variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "lambda_runtime" {
  description = "Runtime for Lambda functions"
  type        = string
  default     = "nodejs18.x"
}

variable "fulfillment_success_rate" {
  description = "Success rate for order fulfillment (0.0 to 1.0)"
  type        = number
  default     = 0.7
}

variable "orders_table_name" {
  description = "Name of the orders DynamoDB table"
  type        = string
}

variable "failed_orders_table_name" {
  description = "Name of the failed orders DynamoDB table"
  type        = string
}

variable "orders_table_arn" {
  description = "ARN of the orders DynamoDB table"
  type        = string
}

variable "failed_orders_table_arn" {
  description = "ARN of the failed orders DynamoDB table"
  type        = string
}

variable "order_queue_url" {
  description = "URL of the order SQS queue"
  type        = string
}

variable "order_queue_arn" {
  description = "ARN of the order SQS queue"
  type        = string
}

variable "order_dlq_url" {
  description = "URL of the order dead letter queue"
  type        = string
}

variable "order_dlq_arn" {
  description = "ARN of the order dead letter queue"
  type        = string
}

variable "step_function_arn" {
  description = "ARN of the Step Function state machine"
  type        = string
  default     = ""
}
