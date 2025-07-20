# DynamoDB Tables
module "dynamodb" {
  source = "./modules/dynamodb"

  project_name = var.project_name
  environment  = var.environment

  tables = {
    orders = {
      hash_key = "order_id"
      attributes = [
        {
          name = "order_id"
          type = "S"
        }
      ]
    }
    failed_orders = {
      hash_key = "order_id"
      attributes = [
        {
          name = "order_id"
          type = "S"
        }
      ]
    }
  }
}

# SQS Queues
module "sqs" {
  source = "./modules/sqs"

  project_name          = var.project_name
  environment           = var.environment
  dlq_max_receive_count = var.dlq_max_receive_count
}

# Lambda Functions
module "lambdas" {
  source = "./modules/lambdas"

  project_name             = var.project_name
  environment              = var.environment
  lambda_runtime           = var.lambda_runtime
  fulfillment_success_rate = var.fulfillment_success_rate

  # Dependencies
  orders_table_name        = module.dynamodb.table_names["orders"]
  failed_orders_table_name = module.dynamodb.table_names["failed_orders"]
  orders_table_arn         = module.dynamodb.table_arns["orders"]
  failed_orders_table_arn  = module.dynamodb.table_arns["failed_orders"]
  order_queue_url          = module.sqs.queue_url
  order_queue_arn          = module.sqs.queue_arn
  order_dlq_url            = module.sqs.dlq_url
  order_dlq_arn            = module.sqs.dlq_arn

  # Step Function ARN will be empty initially, updated later via AWS CLI
  step_function_arn = ""
}

# Step Functions
module "stepfunctions" {
  source = "./modules/stepfunctions"

  project_name = var.project_name
  environment  = var.environment

  # Lambda ARNs from the Lambda module
  validator_lambda_arn     = module.lambdas.lambda_arns["validator"]
  order_storage_lambda_arn = module.lambdas.lambda_arns["order_storage"]

  # SQS
  order_queue_url = module.sqs.queue_url

  depends_on = [module.lambdas]
}

# API Gateway
module "api_gateway" {
  source = "./modules/api_gateway"

  project_name = var.project_name
  environment  = var.environment

  # Lambda integration
  api_handler_lambda_arn           = module.lambdas.lambda_arns["api_handler"]
  api_handler_lambda_function_name = module.lambdas.lambda_function_names["api_handler"]

  # Step Functions
  step_function_arn = module.stepfunctions.state_machine_arn

  depends_on = [module.lambdas, module.stepfunctions]
}

# Monitoring and Alerting
module "monitoring" {
  source = "./modules/monitoring"

  project_name = var.project_name
  environment  = var.environment

  sns_alert_threshold = var.sns_alert_threshold
  order_dlq_name      = module.sqs.dlq_name
}

data "aws_region" "current" {}
