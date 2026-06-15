output "config_recorder_id" {
  value       = module.aws-config.aws_config_configuration_recorder_id
  description = "The ID of the AWS Config configuration recorder"
}

output "config_s3_bucket_name" {
  value       = aws_s3_bucket.config.id
  description = "The name of the S3 bucket created for AWS Config history"
}

output "sns_topic_arn" {
  value       = aws_sns_topic.compliance_alerts.arn
  description = "The ARN of the custom SNS topic for compliance alerts"
}

output "sns_subscription_arn" {
  value       = aws_sns_topic_subscription.email.arn
  description = "The ARN of the email subscription"
}

output "eks_cluster_name" {
  value       = module.eks.cluster_name
  description = "The name of the EKS cluster"
}

output "eks_cluster_arn" {
  value       = module.eks.cluster_arn
  description = "The ARN of the EKS cluster"
}

output "chatbot_slack_arn" {
  value       = aws_chatbot_slack_channel_configuration.slack.chat_configuration_arn
  description = "The ARN of the AWS Chatbot Slack channel configuration"
}

