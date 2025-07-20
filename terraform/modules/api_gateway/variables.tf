variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "api_handler_lambda_arn" {
  description = "ARN of the API handler Lambda function"
  type        = string
}

variable "api_handler_lambda_function_name" {
  description = "Name of the API handler Lambda function"
  type        = string
}

variable "step_function_arn" {
  description = "ARN of the Step Function state machine"
  type        = string
}
