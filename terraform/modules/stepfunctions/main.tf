# IAM Role for Step Functions
resource "aws_iam_role" "step_function_role" {
  name = "${var.project_name}-${var.environment}-step-function-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })
}

# Policy for Step Functions to invoke Lambda functions
resource "aws_iam_policy" "step_function_lambda_policy" {
  name        = "${var.project_name}-${var.environment}-step-function-lambda-policy"
  description = "Policy for Step Functions to invoke Lambda functions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          var.validator_lambda_arn,
          var.order_storage_lambda_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "step_function_lambda_policy" {
  policy_arn = aws_iam_policy.step_function_lambda_policy.arn
  role       = aws_iam_role.step_function_role.name
}

# Step Function State Machine
resource "aws_sfn_state_machine" "order_processing" {
  name     = "${var.project_name}-${var.environment}-order-processing"
  role_arn = aws_iam_role.step_function_role.arn

  definition = jsonencode({
    Comment = "Order Processing Workflow"
    StartAt = "ValidateOrder"
    States = {
      ValidateOrder = {
        Type     = "Task"
        Resource = var.validator_lambda_arn
        Next     = "StoreOrder"
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "ValidationFailed"
            ResultPath  = "$.error"
          }
        ]
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 2
            BackoffRate     = 2.0
          }
        ]
      }

      StoreOrder = {
        Type     = "Task"
        Resource = var.order_storage_lambda_arn
        Next     = "OrderProcessingComplete"
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "StorageFailed"
            ResultPath  = "$.error"
          }
        ]
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 2
            BackoffRate     = 2.0
          }
        ]
      }

      OrderProcessingComplete = {
        Type = "Pass"
        Result = {
          status  = "SUCCESS"
          message = "Order processing completed successfully"
        }
        End = true
      }

      ValidationFailed = {
        Type = "Pass"
        Result = {
          status  = "VALIDATION_FAILED"
          message = "Order validation failed"
        }
        End = true
      }

      StorageFailed = {
        Type = "Pass"
        Result = {
          status  = "STORAGE_FAILED"
          message = "Order storage failed"
        }
        End = true
      }
    }
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-order-processing"
    Project     = var.project_name
    Environment = var.environment
  }
}
