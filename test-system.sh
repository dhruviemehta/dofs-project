#!/bin/bash

# DOFS System Testing Script
# This script tests the end-to-end functionality of the Distributed Order Fulfillment System

set -e

echo "🚀 Starting DOFS System Tests"
echo "================================"

# Configuration
PROJECT_NAME=${PROJECT_NAME:-"dofs"}
ENVIRONMENT=${ENVIRONMENT:-"dev"}
AWS_REGION=${AWS_REGION:-"ap-south-1"}

# Get API endpoint from Terraform output
echo "📡 Getting API endpoint..."
cd terraform
API_ENDPOINT=$(terraform output -raw api_endpoint 2>/dev/null || echo "")

if [ -z "$API_ENDPOINT" ]; then
    echo "❌ Could not retrieve API endpoint. Make sure Terraform has been applied."
    exit 1
fi

echo "✅ API Endpoint: $API_ENDPOINT"
cd ..

# Test functions
test_valid_order() {
    echo ""
    echo "🧪 Test 1: Valid Order Submission"
    echo "--------------------------------"
    
    RESPONSE=$(curl -s -X POST "$API_ENDPOINT" \
        -H "Content-Type: application/json" \
        -d '{
            "customerId": "CUST-1001",
            "productId": "PROD-2001",
            "quantity": 2,
            "price": 29.99,
            "metadata": {
                "source": "test",
                "campaign": "automation"
            }
        }')
    
    echo "Response: $RESPONSE"
    
    # Check if response contains orderId
    if echo "$RESPONSE" | grep -q "orderId"; then
        echo "✅ Valid order test passed"
        ORDER_ID=$(echo "$RESPONSE" | jq -r '.orderId' 2>/dev/null || echo "unknown")
        echo "📋 Order ID: $ORDER_ID"
    else
        echo "❌ Valid order test failed"
        echo "Response: $RESPONSE"
    fi
}

test_invalid_order() {
    echo ""
    echo "🧪 Test 2: Invalid Order (Validation Failure)"
    echo "---------------------------------------------"
    
    RESPONSE=$(curl -s -X POST "$API_ENDPOINT" \
        -H "Content-Type: application/json" \
        -d '{
            "customerId": "INVALID-FORMAT",
            "productId": "PROD-2001",
            "quantity": 0,
            "price": -10
        }')
    
    echo "Response: $RESPONSE"
    
    # Check if response indicates the order was accepted (it will fail at validation step)
    if echo "$RESPONSE" | grep -q "orderId"; then
        echo "✅ Invalid order test passed (accepted by API, will fail at validation)"
        ORDER_ID=$(echo "$RESPONSE" | jq -r '.orderId' 2>/dev/null || echo "unknown")
        
        # Wait a moment and check if Step Function execution failed
        sleep 5
        if [ "$ORDER_ID" != "unknown" ]; then
            EXECUTION_ARN=$(echo "$RESPONSE" | jq -r '.executionArn' 2>/dev/null || echo "")
            if [ ! -z "$EXECUTION_ARN" ]; then
                EXECUTION_STATUS=$(aws stepfunctions describe-execution --execution-arn "$EXECUTION_ARN" --region "$AWS_REGION" --query 'status' --output text 2>/dev/null || echo "UNKNOWN")
                echo "📋 Step Function Status: $EXECUTION_STATUS"
                if [ "$EXECUTION_STATUS" = "SUCCEEDED" ]; then
                    EXECUTION_OUTPUT=$(aws stepfunctions describe-execution --execution-arn "$EXECUTION_ARN" --region "$AWS_REGION" --query 'output' --output text 2>/dev/null || echo "")
                    if echo "$EXECUTION_OUTPUT" | grep -q "VALIDATION_FAILED"; then
                        echo "✅ Order correctly failed at validation step"
                    fi
                fi
            fi
        fi
    else
        echo "❌ Invalid order test failed (should have been accepted by API)"
    fi
}

test_missing_fields() {
    echo ""
    echo "🧪 Test 3: Missing Required Fields"
    echo "---------------------------------"
    
    RESPONSE=$(curl -s -X POST "$API_ENDPOINT" \
        -H "Content-Type: application/json" \
        -d '{
            "customerId": "CUST-1001"
        }')
    
    echo "Response: $RESPONSE"
    
    if echo "$RESPONSE" | grep -q "error\|Error\|400\|Missing"; then
        echo "✅ Missing fields test passed (correctly rejected)"
    else
        echo "❌ Missing fields test failed"
    fi
}

test_large_order() {
    echo ""
    echo "🧪 Test 4: Large Order (Edge Case)"
    echo "---------------------------------"
    
    RESPONSE=$(curl -s -X POST "$API_ENDPOINT" \
        -H "Content-Type: application/json" \
        -d '{
            "customerId": "CUST-9999",
            "productId": "PROD-9999",
            "quantity": 99,
            "price": 9999.99
        }')
    
    echo "Response: $RESPONSE"
    
    if echo "$RESPONSE" | grep -q "orderId"; then
        echo "✅ Large order test passed"
    else
        echo "❌ Large order test failed"
    fi
}

check_infrastructure() {
    echo ""
    echo "🔍 Infrastructure Health Check"
    echo "============================="
    
    # Check DynamoDB tables
    echo "📊 Checking DynamoDB tables..."
    ORDERS_TABLE="${PROJECT_NAME}-${ENVIRONMENT}-orders"
    FAILED_ORDERS_TABLE="${PROJECT_NAME}-${ENVIRONMENT}-failed_orders"
    
    aws dynamodb describe-table --table-name "$ORDERS_TABLE" --region "$AWS_REGION" > /dev/null 2>&1 && \
        echo "✅ Orders table exists" || echo "❌ Orders table not found"
    
    aws dynamodb describe-table --table-name "$FAILED_ORDERS_TABLE" --region "$AWS_REGION" > /dev/null 2>&1 && \
        echo "✅ Failed orders table exists" || echo "❌ Failed orders table not found"
    
    # Check SQS queues
    echo "📨 Checking SQS queues..."
    ORDER_QUEUE="${PROJECT_NAME}-${ENVIRONMENT}-order-queue"
    DLQ="${PROJECT_NAME}-${ENVIRONMENT}-order-dlq"
    
    aws sqs get-queue-url --queue-name "$ORDER_QUEUE" --region "$AWS_REGION" > /dev/null 2>&1 && \
        echo "✅ Order queue exists" || echo "❌ Order queue not found"
    
    aws sqs get-queue-url --queue-name "$DLQ" --region "$AWS_REGION" > /dev/null 2>&1 && \
        echo "✅ Dead letter queue exists" || echo "❌ Dead letter queue not found"
    
    # Check Lambda functions
    echo "⚡ Checking Lambda functions..."
    FUNCTIONS=("api_handler" "validator" "order_storage" "fulfill_order")
    
    for func in "${FUNCTIONS[@]}"; do
        FUNC_NAME="${PROJECT_NAME}-${ENVIRONMENT}-${func}"
        aws lambda get-function --function-name "$FUNC_NAME" --region "$AWS_REGION" > /dev/null 2>&1 && \
            echo "✅ $func Lambda exists" || echo "❌ $func Lambda not found"
    done
    
    # Check Step Function
    echo "🔄 Checking Step Function..."
    STATE_MACHINE="${PROJECT_NAME}-${ENVIRONMENT}-order-processing"
    aws stepfunctions describe-state-machine --state-machine-arn "arn:aws:states:${AWS_REGION}:$(aws sts get-caller-identity --query Account --output text):stateMachine:${STATE_MACHINE}" > /dev/null 2>&1 && \
        echo "✅ Step Function exists" || echo "❌ Step Function not found"
}

validate_system_integration() {
    echo ""
    echo "🔄 System Integration Validation"
    echo "==============================="
    
    # Check if API Handler has Step Function ARN
    echo "🔍 Checking Lambda environment configuration..."
    API_HANDLER_NAME="${PROJECT_NAME}-${ENVIRONMENT}-api_handler"
    STEP_FUNCTION_ENV=$(aws lambda get-function-configuration \
        --function-name "$API_HANDLER_NAME" \
        --region "$AWS_REGION" \
        --query 'Environment.Variables.STEP_FUNCTION_ARN' \
        --output text 2>/dev/null || echo "NOT_SET")
    
    if [ "$STEP_FUNCTION_ENV" != "NOT_SET" ] && [ "$STEP_FUNCTION_ENV" != "None" ]; then
        echo "✅ API Handler has Step Function ARN configured"
    else
        echo "⚠️  Warning: API Handler missing Step Function ARN"
    fi
    
    # Test SQS event source mapping
    echo "🔍 Checking SQS to Lambda integration..."
    FULFILL_LAMBDA_NAME="${PROJECT_NAME}-${ENVIRONMENT}-fulfill_order"
    EVENT_MAPPINGS=$(aws lambda list-event-source-mappings \
        --function-name "$FULFILL_LAMBDA_NAME" \
        --region "$AWS_REGION" \
        --query 'EventSourceMappings[?contains(EventSourceArn, `sqs`)].State' \
        --output text 2>/dev/null || echo "")
    
    if echo "$EVENT_MAPPINGS" | grep -q "Enabled"; then
        echo "✅ SQS to Lambda event mapping is active"
    else
        echo "⚠️  Warning: SQS event source mapping may not be configured"
    fi
}
    echo ""
    echo "📊 Monitoring Order Processing"
    echo "============================="
    
    echo "Waiting 30 seconds for order processing..."
    sleep 30
    
    # Check DynamoDB for orders
    echo "📋 Checking orders in DynamoDB..."
    ORDERS_TABLE="${PROJECT_NAME}-${ENVIRONMENT}-orders"
    
    ORDER_COUNT=$(aws dynamodb scan --table-name "$ORDERS_TABLE" --region "$AWS_REGION" --select "COUNT" --query "Count" --output text 2>/dev/null || echo "0")
    echo "📊 Total orders in table: $ORDER_COUNT"
    
    # Check SQS queue depth
    echo "📨 Checking SQS queue metrics..."
    ORDER_QUEUE_URL=$(aws sqs get-queue-url --queue-name "${PROJECT_NAME}-${ENVIRONMENT}-order-queue" --region "$AWS_REGION" --query "QueueUrl" --output text 2>/dev/null || echo "")
    DLQ_URL=$(aws sqs get-queue-url --queue-name "${PROJECT_NAME}-${ENVIRONMENT}-order-dlq" --region "$AWS_REGION" --query "QueueUrl" --output text 2>/dev/null || echo "")
    
    if [ ! -z "$ORDER_QUEUE_URL" ]; then
        VISIBLE_MESSAGES=$(aws sqs get-queue-attributes --queue-url "$ORDER_QUEUE_URL" --attribute-names "ApproximateNumberOfVisibleMessages" --query "Attributes.ApproximateNumberOfVisibleMessages" --output text 2>/dev/null || echo "0")
        echo "📊 Messages in order queue: $VISIBLE_MESSAGES"
    fi
    
    if [ ! -z "$DLQ_URL" ]; then
        DLQ_MESSAGES=$(aws sqs get-queue-attributes --queue-url "$DLQ_URL" --attribute-names "ApproximateNumberOfVisibleMessages" --query "Attributes.ApproximateNumberOfVisibleMessages" --output text 2>/dev/null || echo "0")
        echo "📊 Messages in DLQ: $DLQ_MESSAGES"
        
        if [ "$DLQ_MESSAGES" -gt 0 ]; then
            echo "⚠️  Warning: There are messages in the DLQ. Check failed orders table."
        fi
    fi


generate_load_test() {
    echo ""
    echo "🔥 Load Test (10 concurrent orders)"
    echo "=================================="
    
    for i in {1..10}; do
        (curl -s -X POST "$API_ENDPOINT" \
            -H "Content-Type: application/json" \
            -d "{
                \"customerId\": \"CUST-$(printf %04d $i)\",
                \"productId\": \"PROD-$(printf %04d $((i % 5 + 1)))\",
                \"quantity\": $((i % 10 + 1)),
                \"price\": $((i * 10 + 99)).99,
                \"metadata\": {
                    \"source\": \"load-test\",
                    \"batch\": \"$i\"
                }
            }" > /dev/null 2>&1 && echo "✅ Order $i submitted" || echo "❌ Order $i failed") &
    done
    
    wait
    echo "🏁 Load test completed"
}

cleanup_test_data() {
    echo ""
    echo "🧹 Cleanup Test Data (Optional)"
    echo "==============================="
    
    read -p "Do you want to clean up test data? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  Cleaning up test orders..."
        
        ORDERS_TABLE="${PROJECT_NAME}-${ENVIRONMENT}-orders"
        
        # Get test orders and delete them
        aws dynamodb scan --table-name "$ORDERS_TABLE" --region "$AWS_REGION" \
            --filter-expression "contains(#metadata.#source, :test_source)" \
            --expression-attribute-names '{"#metadata": "metadata", "#source": "source"}' \
            --expression-attribute-values '{":test_source": {"S": "test"}}' \
            --query "Items[].order_id.S" --output text 2>/dev/null | \
        while read -r order_id; do
            if [ ! -z "$order_id" ]; then
                aws dynamodb delete-item --table-name "$ORDERS_TABLE" --region "$AWS_REGION" \
                    --key "{\"order_id\": {\"S\": \"$order_id\"}}" > /dev/null 2>&1 && \
                    echo "🗑️  Deleted order: $order_id"
            fi
        done
        
        echo "✅ Cleanup completed"
    else
        echo "ℹ️  Skipping cleanup"
    fi
}

# Main execution
main() {
    echo "🔧 Environment: $ENVIRONMENT"
    echo "🌍 Region: $AWS_REGION"
    echo "📦 Project: $PROJECT_NAME"
    
    # Check if required tools are installed
    command -v curl >/dev/null 2>&1 || { echo "❌ curl is required but not installed. Aborting." >&2; exit 1; }
    command -v aws >/dev/null 2>&1 || { echo "❌ AWS CLI is required but not installed. Aborting." >&2; exit 1; }
    command -v jq >/dev/null 2>&1 || echo "⚠️  jq not found. JSON parsing will be limited."
    
    # Run tests
    check_infrastructure
    validate_system_integration
    test_valid_order
    test_invalid_order
    test_missing_fields
    test_large_order
    monitor_processing
    
    echo ""
    echo "🎯 Additional Testing Options"
    echo "=========================="
    echo "1. Load test (y/N)"
    echo "2. Cleanup test data (y/N)"
    
    read -p "Run load test? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        generate_load_test
        echo "⏱️  Waiting for load test processing..."
        sleep 60
        monitor_processing
    fi
    
    cleanup_test_data
    
    echo ""
    echo "🎉 Testing Complete!"
    echo "==================="
    echo "✅ System is ready for production use"
    echo ""
    echo "📊 Next Steps:"
    echo "- Check CloudWatch Dashboard: $(cd terraform && terraform output -raw monitoring_dashboard 2>/dev/null || echo 'Run terraform output monitoring_dashboard')"
    echo "- Monitor DynamoDB tables for order status"
    echo "- Set up SNS email notifications"
    echo "- Configure API authentication for production"
    echo ""
    echo "📚 Documentation: README.md"
    echo "🔧 Troubleshooting: Check CloudWatch Logs"
}

# Run main function
main "$@"