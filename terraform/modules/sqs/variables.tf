variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "dlq_max_receive_count" {
  description = "Maximum receive count before message goes to DLQ"
  type        = number
  default     = 3
}
