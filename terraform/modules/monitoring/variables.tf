variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "sns_alert_threshold" {
  description = "DLQ depth threshold for SNS alerts"
  type        = number
  default     = 5
}

variable "order_dlq_name" {
  description = "Name of the order dead letter queue"
  type        = string
}

variable "alert_email" {
  description = "Email address for alerts"
  type        = string
  default     = ""
}
