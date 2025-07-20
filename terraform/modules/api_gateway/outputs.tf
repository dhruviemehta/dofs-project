output "api_url" {
  description = "URL of the API Gateway"
  value       = "https://${aws_api_gateway_rest_api.dofs_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${var.environment}"
}

output "api_id" {
  description = "ID of the API Gateway"
  value       = aws_api_gateway_rest_api.dofs_api.id
}

output "order_endpoint" {
  description = "Full URL for the order endpoint"
  value       = "https://${aws_api_gateway_rest_api.dofs_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${var.environment}/order"
}
