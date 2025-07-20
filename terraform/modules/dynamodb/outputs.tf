output "table_names" {
  description = "Names of the DynamoDB tables"
  value = {
    for k, v in aws_dynamodb_table.tables : k => v.name
  }
}

output "table_arns" {
  description = "ARNs of the DynamoDB tables"
  value = {
    for k, v in aws_dynamodb_table.tables : k => v.arn
  }
}
