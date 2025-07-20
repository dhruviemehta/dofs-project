output "queue_url" {
  description = "URL of the main order queue"
  value       = aws_sqs_queue.order_queue.url
}

output "queue_arn" {
  description = "ARN of the main order queue"
  value       = aws_sqs_queue.order_queue.arn
}

output "dlq_url" {
  description = "URL of the dead letter queue"
  value       = aws_sqs_queue.order_dlq.url
}

output "dlq_arn" {
  description = "ARN of the dead letter queue"
  value       = aws_sqs_queue.order_dlq.arn
}

output "dlq_name" {
  description = "Name of the dead letter queue"
  value       = aws_sqs_queue.order_dlq.name
}

output "sqs_policy_arn" {
  description = "ARN of the SQS IAM policy"
  value       = aws_iam_policy.sqs_policy.arn
}
