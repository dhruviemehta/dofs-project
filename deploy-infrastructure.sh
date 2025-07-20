#!/bin/bash

# Two-stage deployment script to handle circular dependency between Lambda and Step Functions

set -e

echo "🚀 Deploying DOFS Infrastructure"
echo "================================="

# Configuration
PROJECT_NAME=${PROJECT_NAME:-"dofs"}
ENVIRONMENT=${ENVIRONMENT:-"dev"}
AWS_REGION=${AWS_REGION:-"ap-south-1"}

echo "📋 Configuration:"
echo "  Project: $PROJECT_NAME"
echo "  Environment: $ENVIRONMENT"
echo "  Region: $AWS_REGION"
echo ""

# Check if we're in the terraform directory
if [ ! -f "main.tf" ]; then
    if [ -d "terraform" ]; then
        echo "📁 Changing to terraform directory..."
        cd terraform
    else
        echo "❌ Error: terraform directory not found!"
        exit 1
    fi
fi

# Install Lambda dependencies
echo "📦 Installing Lambda dependencies..."
cd ../lambdas/api_handler && npm install
cd ../validator && npm install || true
cd ../order_storage && npm install
cd ../fulfill_order && npm install
cd ../../terraform

# Stage 1: Deploy infrastructure without Step Functions
echo "1️⃣ Stage 1: Deploying core infrastructure..."
terraform apply \
  -target="module.dynamodb" \
  -target="module.sqs" \
  -target="module.lambdas" \
  -target="module.monitoring" \
  -var="project_name=$PROJECT_NAME" \
  -var="environment=$ENVIRONMENT" \
  -var="aws_region=$AWS_REGION" \
  -auto-approve

echo "✅ Stage 1 complete - Core infrastructure deployed"

# Stage 2: Deploy Step Functions and API Gateway
echo "2️⃣ Stage 2: Deploying Step Functions and API Gateway..."
terraform apply \
  -var="project_name=$PROJECT_NAME" \
  -var="environment=$ENVIRONMENT" \
  -var="aws_region=$AWS_REGION" \
  -auto-approve

echo "✅ Stage 2 complete - Step Functions and API Gateway deployed"

# Stage 3: Update Lambda function with Step Function ARN
echo "3️⃣ Stage 3: Updating API handler with Step Function ARN..."

STEP_FUNCTION_ARN=$(terraform output -raw step_function_arn)
API_HANDLER_NAME=$(terraform output -json lambda_functions | jq -r '.api_handler')

# Create a temporary JSON file for the environment variables
cat > /tmp/lambda_env.json <<EOF
{
  "Variables": {
    "PROJECT_NAME": "$PROJECT_NAME",
    "ENVIRONMENT": "$ENVIRONMENT",
    "STEP_FUNCTION_ARN": "$STEP_FUNCTION_ARN"
  }
}
EOF

aws lambda update-function-configuration \
  --function-name "$API_HANDLER_NAME" \
  --environment file:///tmp/lambda_env.json \
  --region "$AWS_REGION"

# Clean up temp file
rm -f /tmp/lambda_env.json

echo "✅ Stage 3 complete - Lambda function updated with Step Function ARN"

# Verify the update worked
echo "🔍 Verifying Lambda environment variables..."
LAMBDA_ENV_CHECK=$(aws lambda get-function-configuration \
  --function-name "$API_HANDLER_NAME" \
  --region "$AWS_REGION" \
  --query 'Environment.Variables.STEP_FUNCTION_ARN' \
  --output text 2>/dev/null || echo "ERROR")

if [ "$LAMBDA_ENV_CHECK" = "$STEP_FUNCTION_ARN" ]; then
  echo "✅ Lambda environment variables updated successfully"
else
  echo "⚠️  Warning: Lambda environment may not be updated correctly"
  echo "   Expected: $STEP_FUNCTION_ARN"
  echo "   Got: $LAMBDA_ENV_CHECK"
fi

echo ""
echo "🎉 Deployment Complete!"
echo "======================="
echo "✅ All infrastructure deployed successfully"
echo ""

# Show important outputs
echo "📊 Important Endpoints:"
API_ENDPOINT=$(terraform output -raw api_endpoint 2>/dev/null || echo "Not available")
DASHBOARD_URL=$(terraform output -raw monitoring_dashboard 2>/dev/null || echo "Not available")

echo "  API Endpoint: $API_ENDPOINT"
echo "  Dashboard: $DASHBOARD_URL"
echo ""

echo "🧪 Next Steps:"
echo "  1. Test the system: cd .. && ./test-system.sh"
echo "  2. Monitor via CloudWatch Dashboard"
echo "  3. Check DynamoDB tables for order processing"
echo ""

echo "🚀 Quick API Test:"
echo "curl -X POST $API_ENDPOINT \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{"
echo "    \"customerId\": \"CUST-1001\","
echo "    \"productId\": \"PROD-2001\","
echo "    \"quantity\": 2,"
echo "    \"price\": 29.99"
echo "  }'"
echo ""

echo "🚀 System is ready for testing!"