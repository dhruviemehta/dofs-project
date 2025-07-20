# Distributed Order Fulfillment System (DOFS)

A production-grade serverless order fulfillment system built with AWS services, Terraform, and CI/CD pipelines.

## Architecture Overview

```
POST /order → API Gateway → Lambda (API Handler) 
    ↓
Step Function Orchestrator
    ↓
[Validate Order] → [Store Order] → [SQS Queue]
    ↓
Fulfillment Lambda (70% success rate)
    ↓
DynamoDB Update (FULFILLED/FAILED) + DLQ for failures
```

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- Node.js >= 18
- Git
- GitHub repository (optional, can use CodeCommit)
- `jq` for JSON processing (recommended)

## Quick Start

### 1. Clone and Setup

```bash
git clone <your-repo-url>
cd dofs-project

# Set environment variables
export AWS_REGION=ap-south-1
export PROJECT_NAME=dofs
export ENVIRONMENT=dev
```

### 2. Automated Backend Setup

```bash
# Run the automated backend setup script
chmod +x setup-backend.sh
./setup-backend.sh
```

This script will:
- Create S3 bucket with unique name for Terraform state
- Create DynamoDB table for state locking
- Configure remote backend automatically
- Migrate local state to remote backend

### 3. Deploy Complete Infrastructure

⚠️ CRITICAL: Circular Dependency Issue

WARNING: This system has a circular dependency between Lambda functions and Step Functions that must be handled carefully:

Lambda functions need the Step Function ARN as an environment variable
Step Functions need Lambda function ARNs to define the workflow
This creates a Terraform cycle that prevents normal deployment

SOLUTION: The deployment scripts use a 3-stage approach to break this cycle:

Deploy Lambda functions with step_function_arn = ""
Deploy Step Functions using Lambda ARNs
Update Lambda environment variables via AWS CLI

DO NOT try to pass module.stepfunctions.state_machine_arn directly to the Lambda module - this will cause a Terraform cycle error!

```bash
# Run the automated deployment script
chmod +x deploy-infrastructure.sh
./deploy-infrastructure.sh
```

The deployment script performs a **3-stage deployment**:
1. **Stage 1**: Core infrastructure (DynamoDB, SQS, Lambda, Monitoring)
2. **Stage 2**: Step Functions and API Gateway
3. **Stage 3**: Update Lambda with Step Function ARN

### 4. Validate System

```bash
# Run comprehensive system validation
chmod +x validate-system.sh
./validate-system.sh
```

### 5. Test the System

```bash
# Run the complete test suite
chmod +x test-system.sh
./test-system.sh
```

## Testing Your System

### Automated Testing

The test suite includes:
- **Infrastructure Health Check**: Validates all AWS services
- **System Integration Check**: Validates configurations and mappings
- **Valid Order Tests**: Tests successful order processing
- **Invalid Order Tests**: Tests validation failures
- **Edge Case Tests**: Tests boundary conditions
- **Load Testing**: Optional concurrent order processing

### Manual Testing

#### Quick API Test

```bash
# Test a valid order
curl -X POST https://your-api-endpoint/dev/order \
  -H "Content-Type: application/json" \
  -d '{
    "customerId": "CUST-1001",
    "productId": "PROD-2001",
    "quantity": 2,
    "price": 29.99,
    "metadata": {
      "source": "manual-test"
    }
  }'
```

Expected response:
```json
{
  "orderId": "uuid-generated",
  "status": "ACCEPTED",
  "executionArn": "arn:aws:states:...",
  "message": "Order received and processing started"
}
```

#### Test Invalid Order

```bash
# Test validation failure
curl -X POST https://your-api-endpoint/dev/order \
  -H "Content-Type: application/json" \
  -d '{
    "customerId": "INVALID-FORMAT",
    "productId": "PROD-2001",
    "quantity": 0,
    "price": -10
  }'
```

### Monitor Processing

1. **CloudWatch Dashboard**: Real-time metrics and logs
2. **DynamoDB Tables**: 
   - `dofs-dev-orders`: View order status updates
   - `dofs-dev-failed_orders`: View failed orders from DLQ
3. **SQS Queues**: Monitor message flow and DLQ depth
4. **Step Functions**: View execution logs and workflow status

## CI/CD Pipeline

### Setup GitHub Integration

```bash
cd terraform/cicd

terraform apply \
  -var="github_repo=your-username/dofs-project" \
  -var="github_token=your-github-token" \
  -var="project_name=$PROJECT_NAME" \
  -var="environment=$ENVIRONMENT" \
  -var="aws_region=$AWS_REGION"
```

### Pipeline Stages

1. **Source**: GitHub or CodeCommit
2. **Build Lambda**: Package Lambda functions with dependencies
3. **Plan**: Run `terraform plan`
4. **Manual Approval**: Review changes
5. **Deploy**: Run `terraform apply`

## Monitoring and Alerting

### CloudWatch Metrics

- **Lambda Functions**: Duration, errors, invocations
- **SQS Queues**: Message counts, DLQ depth
- **Step Functions**: Execution success/failure rates
- **API Gateway**: Latency, error rates
- **DynamoDB**: Read/write capacity, throttling

### Alerts

- DLQ depth > 5 messages triggers SNS alert
- Lambda function errors
- API Gateway 5XX errors
- Step Function execution failures

## System Features

### Core Capabilities

- ✅ **Event-driven Architecture**: Serverless, auto-scaling
- ✅ **Order Validation**: Business rules and format validation
- ✅ **Workflow Orchestration**: Step Functions with retry logic
- ✅ **Asynchronous Processing**: SQS queuing with DLQ
- ✅ **70% Success Rate Simulation**: Realistic fulfillment processing
- ✅ **Complete Order Lifecycle**: PENDING → PROCESSING → FULFILLED/FAILED
- ✅ **Error Handling**: Comprehensive retry and DLQ strategies
- ✅ **Monitoring**: Real-time dashboards and alerting

### Production Features

- ✅ **Infrastructure as Code**: Modular Terraform design
- ✅ **CI/CD Pipeline**: Automated deployment with approval gates
- ✅ **Remote State Management**: S3 backend with DynamoDB locking
- ✅ **Multi-Environment Support**: Dev/staging/prod separation
- ✅ **Comprehensive Testing**: Automated test suite
- ✅ **System Validation**: Health checks and integration tests

## Troubleshooting

### Common Issues

1. **Backend Setup Issues**: 
   - Run `./setup-backend.sh` from project root
   - Ensure AWS CLI is configured with proper permissions
   - Check that S3 bucket names are globally unique

2. **Lambda Environment Variables**: 
   - The deployment script automatically updates API Handler with Step Function ARN
   - Check validation script output for configuration issues

3. **Step Function Failures**: 
   - Check CloudWatch logs for Lambda function errors
   - Validate order format meets business rules
   - Ensure Lambda functions have proper IAM permissions

4. **SQS Processing Issues**:
   - Check SQS event source mapping is enabled
   - Verify fulfillment Lambda has DynamoDB permissions
   - Monitor DLQ for failed messages

5. **API Gateway Errors**:
   - Verify Lambda integration and permissions
   - Check CloudWatch logs for detailed error messages
   - Validate request format matches API model

### Debug Commands

```bash
# Check system health
./validate-system.sh

# Run comprehensive tests
./test-system.sh

# Check specific order processing
aws dynamodb get-item \
  --table-name dofs-dev-orders \
  --key '{"order_id":{"S":"your-order-id"}}' \
  --region ap-south-1

# Check Step Function executions
aws stepfunctions list-executions \
  --state-machine-arn $(cd terraform && terraform output -raw step_function_arn) \
  --region ap-south-1 \
  --max-items 5
```

### Backend Recovery

If you need to recreate the backend:

```bash
# Delete current state (be careful!)
rm -rf terraform/.terraform/ terraform/terraform.tfstate*

# Run setup script again
./setup-backend.sh
```

## Production Deployment

### Environment Promotion

```bash
# Deploy to staging
export ENVIRONMENT=staging
./setup-backend.sh  # Creates separate backend for staging
./deploy-infrastructure.sh

# Deploy to production
export ENVIRONMENT=prod
./setup-backend.sh  # Creates separate backend for production
./deploy-infrastructure.sh
```

### Production Considerations

1. **Scaling**: Configure reserved concurrency for Lambda functions
2. **Security**: 
   - Enable WAF for API Gateway
   - Use VPC endpoints for internal communication
   - Implement API authentication (OAuth, API Keys)
3. **Backup**: Enable point-in-time recovery for DynamoDB
4. **Monitoring**: Set up detailed CloudWatch alarms and notifications
5. **Compliance**: Implement data encryption and audit logging

## Architecture Decisions

### Why Serverless?

- **Cost Effective**: Pay only for what you use
- **Auto Scaling**: Handles traffic spikes automatically
- **Managed Infrastructure**: AWS handles server management
- **High Availability**: Built-in redundancy across AZs

### Why Step Functions?

- **Visual Workflow**: Easy to understand and debug
- **Error Handling**: Built-in retry and error handling
- **State Management**: Maintains execution state
- **Integration**: Native integration with AWS services

### Why DLQ?

- **Reliability**: Ensures no message loss
- **Debugging**: Failed messages preserved for analysis
- **Alerting**: Triggers notifications for manual intervention

### Why Remote Backend?

- **Team Collaboration**: Shared state across team members
- **State Locking**: Prevents concurrent modifications
- **Versioning**: S3 versioning for state history
- **Security**: Encrypted storage with access controls

## File Structure

```
dofs-project/
├── lambdas/                    # Lambda function source code
│   ├── api_handler/           # API Gateway handler
│   ├── validator/             # Order validation logic
│   ├── order_storage/         # DynamoDB storage + SQS
│   └── fulfill_order/         # SQS processor (70% success)
├── terraform/                 # Infrastructure as Code
│   ├── modules/               # Reusable Terraform modules
│   │   ├── api_gateway/      # API Gateway + Lambda integration
│   │   ├── lambdas/          # Lambda functions + IAM
│   │   ├── dynamodb/         # DynamoDB tables
│   │   ├── sqs/              # SQS + DLQ
│   │   ├── stepfunctions/    # Step Functions workflow
│   │   └── monitoring/       # CloudWatch + SNS
│   └── cicd/                 # CI/CD pipeline configuration
├── setup-backend.sh          # Automated backend setup script
├── deploy-infrastructure.sh  # 3-stage deployment script
├── validate-system.sh        # System health validation
├── test-system.sh           # End-to-end testing script
├── buildspec.yml             # CodeBuild specification
├── lambda-buildspec.yml      # Lambda build specification
└── README.md                 # This file
```

## Success Metrics

- ✅ **Orders processed end-to-end**
- ✅ **70% fulfillment success rate simulation**
- ✅ **Failed orders captured in DLQ**
- ✅ **Automated infrastructure deployment**
- ✅ **Real-time monitoring and alerting**
- ✅ **Production-ready architecture**
- ✅ **Comprehensive testing coverage**
- ✅ **Complete CI/CD pipeline**

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and test thoroughly using `./test-system.sh`
4. Validate system health with `./validate-system.sh`
5. Submit a pull request with detailed description

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Built with ❤️ using AWS Serverless Services, Terraform, and DevOps best practices**