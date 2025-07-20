# IAM Role for Lambda functions
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-${var.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

# DynamoDB access policy
resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "${var.project_name}-${var.environment}-lambda-dynamodb-policy"
  description = "Policy for Lambda functions to access DynamoDB tables"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          var.orders_table_arn,
          var.failed_orders_table_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy" {
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
  role       = aws_iam_role.lambda_role.name
}

# SQS access policy
resource "aws_iam_policy" "lambda_sqs_policy" {
  name        = "${var.project_name}-${var.environment}-lambda-sqs-policy"
  description = "Policy for Lambda functions to access SQS queues"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [
          var.order_queue_arn,
          var.order_dlq_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_sqs_policy" {
  policy_arn = aws_iam_policy.lambda_sqs_policy.arn
  role       = aws_iam_role.lambda_role.name
}

# Step Functions access policy for API handler
resource "aws_iam_policy" "lambda_stepfunctions_policy" {
  name        = "${var.project_name}-${var.environment}-lambda-stepfunctions-policy"
  description = "Policy for Lambda functions to access Step Functions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_stepfunctions_policy" {
  policy_arn = aws_iam_policy.lambda_stepfunctions_policy.arn
  role       = aws_iam_role.lambda_role.name
}

# Lambda function definitions
locals {
  lambda_functions = {
    api_handler = {
      source_dir = "../lambdas/api_handler"
      handler    = "index.handler"
      environment_variables = {
        STEP_FUNCTION_ARN = var.step_function_arn
      }
    }
    validator = {
      source_dir            = "../lambdas/validator"
      handler               = "index.handler"
      environment_variables = {}
    }
    order_storage = {
      source_dir = "../lambdas/order_storage"
      handler    = "index.handler"
      environment_variables = {
        ORDERS_TABLE_NAME = var.orders_table_name
        ORDER_QUEUE_URL   = var.order_queue_url
      }
    }
    fulfill_order = {
      source_dir = "../lambdas/fulfill_order"
      handler    = "index.handler"
      environment_variables = {
        ORDERS_TABLE_NAME        = var.orders_table_name
        FAILED_ORDERS_TABLE_NAME = var.failed_orders_table_name
        FULFILLMENT_SUCCESS_RATE = tostring(var.fulfillment_success_rate)
        DLQ_MAX_RECEIVE_COUNT    = "3"
      }
    }
  }
}

# Create ZIP files for Lambda functions
data "archive_file" "lambda_zip" {
  for_each = local.lambda_functions

  type        = "zip"
  source_dir  = each.value.source_dir
  output_path = "${path.module}/lambda_${each.key}.zip"
}

# Lambda functions
resource "aws_lambda_function" "functions" {
  for_each = local.lambda_functions

  filename      = data.archive_file.lambda_zip[each.key].output_path
  function_name = "${var.project_name}-${var.environment}-${each.key}"
  role          = aws_iam_role.lambda_role.arn
  handler       = each.value.handler
  runtime       = var.lambda_runtime
  timeout       = 30
  memory_size   = 256

  source_code_hash = data.archive_file.lambda_zip[each.key].output_base64sha256

  environment {
    variables = merge(
      {
        PROJECT_NAME = var.project_name
        ENVIRONMENT  = var.environment
      },
      each.value.environment_variables
    )
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy_attachment.lambda_dynamodb_policy,
    aws_iam_role_policy_attachment.lambda_sqs_policy,
    aws_iam_role_policy_attachment.lambda_stepfunctions_policy
  ]
}

# SQS trigger for fulfillment Lambda
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn                   = var.order_queue_arn
  function_name                      = aws_lambda_function.functions["fulfill_order"].arn
  batch_size                         = 10
  maximum_batching_window_in_seconds = 5
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "lambda_logs" {
  for_each = local.lambda_functions

  name              = "/aws/lambda/${aws_lambda_function.functions[each.key].function_name}"
  retention_in_days = 7
}

data "aws_region" "current" {}
