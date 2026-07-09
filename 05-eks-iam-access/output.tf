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

output "chatbot_slack_arn" {
  value       = aws_chatbot_slack_channel_configuration.slack.chat_configuration_arn
  description = "The ARN of the AWS Chatbot Slack channel configuration"
}

output "config_rule_name" {
  value       = "IAM_POLICY_NO_STATEMENTS_WITH_ADMIN_ACCESS"
  description = "The AWS Config managed rule deployed by this stack"
}

output "violation_policy_name" {
  value       = aws_iam_policy.wildcard_admin_backdoor.name
  description = "The name of the wildcard admin policy created for testing"
}

output "violation_policy_arn" {
  value       = aws_iam_policy.wildcard_admin_backdoor.arn
  description = "The ARN of the wildcard admin policy created for testing"
}
