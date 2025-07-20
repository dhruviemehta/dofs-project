# SNS Topic for alerts
resource "aws_sns_topic" "dofs_alerts" {
  name = "${var.project_name}-${var.environment}-alerts"
}

# SNS Topic subscription (email)
resource "aws_sns_topic_subscription" "email_alerts" {
  topic_arn = aws_sns_topic.dofs_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email

  count = var.alert_email != "" ? 1 : 0
}

# CloudWatch Alarm for DLQ depth
resource "aws_cloudwatch_metric_alarm" "dlq_depth_alarm" {
  alarm_name          = "${var.project_name}-${var.environment}-dlq-depth-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ApproximateNumberOfVisibleMessages"
  namespace           = "AWS/SQS"
  period              = "60"
  statistic           = "Average"
  threshold           = var.sns_alert_threshold
  alarm_description   = "This metric monitors DLQ depth"
  alarm_actions       = [aws_sns_topic.dofs_alerts.arn]

  dimensions = {
    QueueName = var.order_dlq_name
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "dofs_dashboard" {
  dashboard_name = "${var.project_name}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", "${var.project_name}-${var.environment}-api_handler"],
            [".", "Errors", ".", "."],
            [".", "Invocations", ".", "."],
            ["AWS/Lambda", "Duration", "FunctionName", "${var.project_name}-${var.environment}-validator"],
            [".", "Errors", ".", "."],
            [".", "Invocations", ".", "."],
            ["AWS/Lambda", "Duration", "FunctionName", "${var.project_name}-${var.environment}-order_storage"],
            [".", "Errors", ".", "."],
            [".", "Invocations", ".", "."],
            ["AWS/Lambda", "Duration", "FunctionName", "${var.project_name}-${var.environment}-fulfill_order"],
            [".", "Errors", ".", "."],
            [".", "Invocations", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Lambda Function Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/SQS", "NumberOfMessagesSent", "QueueName", "${var.project_name}-${var.environment}-order-queue"],
            [".", "NumberOfMessagesReceived", ".", "."],
            [".", "ApproximateNumberOfVisibleMessages", ".", "."],
            ["AWS/SQS", "ApproximateNumberOfVisibleMessages", "QueueName", var.order_dlq_name]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "SQS Queue Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/States", "ExecutionTime", "StateMachineArn", "${var.project_name}-${var.environment}-order-processing"],
            [".", "ExecutionsFailed", ".", "."],
            [".", "ExecutionsSucceeded", ".", "."],
            [".", "ExecutionsStarted", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Step Functions Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", "${var.project_name}-${var.environment}-api"],
            [".", "Latency", ".", "."],
            [".", "4XXError", ".", "."],
            [".", "5XXError", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "API Gateway Metrics"
          period  = 300
        }
      }
    ]
  })
}

# Custom CloudWatch Log Group for application logs
resource "aws_cloudwatch_log_group" "application_logs" {
  name              = "/aws/dofs/${var.project_name}-${var.environment}"
  retention_in_days = 7
}

data "aws_region" "current" {}
