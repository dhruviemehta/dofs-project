output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = module.api_gateway.order_endpoint
}

output "api_url" {
  description = "API Gateway base URL"
  value       = module.api_gateway.api_url
}

output "step_function_arn" {
  description = "Step Function state machine ARN"
  value       = module.stepfunctions.state_machine_arn
}

output "step_function_name" {
  description = "Step Function state machine name"
  value       = module.stepfunctions.state_machine_name
}

output "dynamodb_tables" {
  description = "DynamoDB table names"
  value       = module.dynamodb.table_names
}

output "sqs_queues" {
  description = "SQS queue information"
  value = {
    order_queue_url = module.sqs.queue_url
    dlq_url         = module.sqs.dlq_url
  }
}

output "lambda_functions" {
  description = "Lambda function names"
  value       = module.lambdas.lambda_function_names
}

output "monitoring_dashboard" {
  description = "CloudWatch dashboard URL"
  value       = module.monitoring.dashboard_url
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = module.monitoring.sns_topic_arn
}
