# Dead Letter Queue
resource "aws_sqs_queue" "order_dlq" {
  name = "${var.project_name}-${var.environment}-order-dlq"

  message_retention_seconds = 1209600 # 14 days

  tags = {
    Name        = "${var.project_name}-${var.environment}-order-dlq"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Main Order Queue
resource "aws_sqs_queue" "order_queue" {
  name = "${var.project_name}-${var.environment}-order-queue"

  visibility_timeout_seconds = 300     # 5 minutes
  message_retention_seconds  = 1209600 # 14 days

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.order_dlq.arn
    maxReceiveCount     = var.dlq_max_receive_count
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-order-queue"
    Project     = var.project_name
    Environment = var.environment
  }
}

# IAM policy for Lambda to access SQS
resource "aws_iam_policy" "sqs_policy" {
  name        = "${var.project_name}-${var.environment}-sqs-policy"
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
          aws_sqs_queue.order_queue.arn,
          aws_sqs_queue.order_dlq.arn
        ]
      }
    ]
  })
}
