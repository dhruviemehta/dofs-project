
# Variables
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-south-1"
}

variable "github_repo" {
  description = "GitHub repository for CI/CD (owner/repo format)"
  type        = string
}

variable "github_token" {
  description = "GitHub personal access token"
  type        = string
  sensitive   = true
}

variable "github_branch" {
  description = "GitHub branch for CI/CD"
  type        = string
  default     = "main"
}
