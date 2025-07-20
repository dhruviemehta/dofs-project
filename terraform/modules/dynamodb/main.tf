resource "aws_dynamodb_table" "tables" {
  for_each = var.tables

  name         = "${var.project_name}-${var.environment}-${each.key}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = each.value.hash_key

  dynamic "attribute" {
    for_each = each.value.attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-${each.key}"
    Project     = var.project_name
    Environment = var.environment
  }
}
