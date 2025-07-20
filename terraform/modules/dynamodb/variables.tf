variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "tables" {
  description = "Map of DynamoDB table configurations"
  type = map(object({
    hash_key = string
    attributes = list(object({
      name = string
      type = string
    }))
  }))
}
