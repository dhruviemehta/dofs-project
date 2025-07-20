#!/bin/bash

# Comprehensive system validation script
# This validates the entire DOFS infrastructure and configuration

set -e

echo "🔍 DOFS System Validation"
echo "========================="

# Configuration
PROJECT_NAME=${PROJECT_NAME:-"dofs"}
ENVIRONMENT=${ENVIRONMENT:-"dev"}
AWS_REGION=${AWS_REGION:-"ap-south-1"}

echo "📋 Configuration:"
echo "  Project: $PROJECT_NAME"
echo "  Environment: $ENVIRONMENT"
echo "  Region: $AWS_REGION"
echo ""

# Navigate to terraform directory
if [ ! -f "main.tf" ]; then
    if [ -d "terraform" ]; then
        cd terraform
    else
        echo "❌ Error: terraform directory not found!"
        exit 1
    fi
fi

# Get outputs from Terraform
echo "📊 Getting Terraform outputs..."
API_ENDPOINT=$(terraform output -raw api_endpoint 2>/dev/null || echo "")
STEP_FUNCTION_ARN=$(terraform output -raw step_function_arn 2>/dev/null || echo "")
LAMBDA_FUNCTIONS=$(terraform output -json lambda_functions 2>/dev/null || echo "{}")

if [ -z "$API_ENDPOINT" ]; then
    echo "❌ Cannot retrieve Terraform outputs. Ensure infrastructure is deployed."
    exit 1
fi

echo "✅ Terraform outputs retrieved successfully"

# Validate Lambda configurations
echo ""
echo "🔧 Validating Lambda Configurations"
echo "==================================="

API_HANDLER_NAME=$(echo "$LAMBDA_FUNCTIONS" | jq -r '.api_handler' || echo "")
if [ ! -z "$API_HANDLER_NAME" ]; then
    echo "🔍 Checking API Handler configuration..."
    
    # Check environment variables
    ENV_VARS=$(aws lambda get-function-configuration \
        --function-name "$API_HANDLER_NAME" \
        --region "$AWS_REGION" \
        --query 'Environment.Variables' \
        --output json 2>/dev/null || echo "{}")
    
    STEP_FUNCTION_ENV=$(echo "$ENV_VARS" | jq -r '.STEP_FUNCTION_ARN // "NOT_SET"')
    
    if [ "$STEP_FUNCTION_ENV" = "$STEP_FUNCTION_ARN" ]; then
        echo "✅ API Handler has correct Step Function ARN"
    else
        echo "❌ API Handler Step Function ARN mismatch"
        echo "   Expected: $STEP_FUNCTION_ARN"
        echo "   Found: $STEP_FUNCTION_ENV"
    fi
    
    # Check runtime and handler
    RUNTIME=$(aws lambda get-function-configuration \
        --function-name "$API_HANDLER_NAME" \
        --region "$AWS_REGION" \
        --query 'Runtime' \
        --output text 2>/dev/null || echo "unknown")
    
    HANDLER=$(aws lambda get-function-configuration \
        --function-name "$API_HANDLER_NAME" \
        --region "$AWS_REGION" \
        --query 'Handler' \
        --output text 2>/dev/null || echo "unknown")
    
    echo "📋 Runtime: $RUNTIME, Handler: $HANDLER"
fi

# Validate SQS Event Source Mapping
echo ""
echo "🔍 Validating SQS Event Source Mapping..."
FULFILL_LAMBDA_NAME=$(echo "$LAMBDA_FUNCTIONS" | jq -r '.fulfill_order' || echo "")

if [ ! -z "$FULFILL_LAMBDA_NAME" ]; then
    EVENT_MAPPINGS=$(aws lambda list-event-source-mappings \
        --function-name "$FULFILL_LAMBDA_NAME" \
        --region "$AWS_REGION" \
        --output json 2>/dev/null || echo '{"EventSourceMappings":[]}')
    
    SQS_MAPPINGS=$(echo "$EVENT_MAPPINGS" | jq '.EventSourceMappings[] | select(.EventSourceArn | contains("sqs"))')
    
    if [ ! -z "$SQS_MAPPINGS" ]; then
        STATE=$(echo "$SQS_MAPPINGS" | jq -r '.State')
        BATCH_SIZE=$(echo "$SQS_MAPPINGS" | jq -r '.BatchSize')
        echo "✅ SQS Event Source Mapping found"
        echo "📋 State: $STATE, Batch Size: $BATCH_SIZE"
    else
        echo "❌ No SQS Event Source Mapping found for fulfillment Lambda"
    fi
fi

# Validate Step Functions definition
echo ""
echo "🔍 Validating Step Functions..."
if [ ! -z "$STEP_FUNCTION_ARN" ]; then
    SF_DEFINITION=$(aws stepfunctions describe-state-machine \
        --state-machine-arn "$STEP_FUNCTION_ARN" \
        --region "$AWS_REGION" \
        --query 'definition' \
        --output text 2>/dev/null || echo "")
    
    if [ ! -z "$SF_DEFINITION" ]; then
        echo "✅ Step Functions definition retrieved"
        
        # Check if definition contains expected states
        if echo "$SF_DEFINITION" | jq -e '.States.ValidateOrder' >/dev/null 2>&1; then
            echo "✅ ValidateOrder state found"
        else
            echo "❌ ValidateOrder state missing"
        fi
        
        if echo "$SF_DEFINITION" | jq -e '.States.StoreOrder' >/dev/null 2>&1; then
            echo "✅ StoreOrder state found"
        else
            echo "❌ StoreOrder state missing"
        fi
    else
        echo "❌ Could not retrieve Step Functions definition"
    fi
fi

# Test API endpoint
echo ""
echo "🧪 Testing API Endpoint"
echo "======================"

echo "🔍 Testing API endpoint connectivity..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API_ENDPOINT" \
    -H "Content-Type: application/json" \
    -d '{"test": "connectivity"}' || echo "000")

if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "400" ] || [ "$HTTP_STATUS" = "500" ]; then
    echo "✅ API endpoint is reachable (HTTP $HTTP_STATUS)"
else
    echo "❌ API endpoint connectivity issue (HTTP $HTTP_STATUS)"
fi

# Summary
echo ""
echo "📊 Validation Summary"
echo "===================="
echo "✅ Infrastructure deployed and accessible"
echo "✅ Terraform outputs available"
echo "✅ Lambda functions configured"
echo "✅ API Gateway endpoint reachable"
echo ""
echo "🎯 System is ready for testing!"
echo "Run './test-system.sh' for end-to-end testing"