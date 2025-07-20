variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "dofs"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "github_repo" {
  description = "GitHub repository for CI/CD"
  type        = string
  default     = ""
}

variable "github_branch" {
  description = "GitHub branch for CI/CD"
  type        = string
  default     = "main"
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

variable "dlq_max_receive_count" {
  description = "Maximum receive count before message goes to DLQ"
  type        = number
  default     = 3
}

variable "sns_alert_threshold" {
  description = "DLQ depth threshold for SNS alerts"
  type        = number
  default     = 5
}

# Computed locals
locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
