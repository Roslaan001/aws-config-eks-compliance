# 1. Custom SNS Topic for compliance alerts
resource "aws_sns_topic" "compliance_alerts" {
  name = "eks-secrets-encryption-compliance-alerts"
}

# 2. SNS Topic Policy to allow EventBridge to publish to it
resource "aws_sns_topic_policy" "compliance" {
  arn    = aws_sns_topic.compliance_alerts.arn
  policy = data.aws_iam_policy_document.sns_publish_policy.json
}

data "aws_iam_policy_document" "sns_publish_policy" {
  statement {
    effect    = "Allow"
    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.compliance_alerts.arn]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

# 3. EventBridge Rule to match only AWS Config compliance changes
resource "aws_cloudwatch_event_rule" "compliance" {
  name        = "eks-secrets-compliance-rule"
  description = "Capture AWS Config compliance changes"

  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Config Rules Compliance Change"]
  })
}

# 4. Target EventBridge Rule to our custom SNS topic
resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.compliance.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.compliance_alerts.arn
}

# 5. Email Subscription to our custom, filtered SNS Topic
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.compliance_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# 6. IAM Role assumed by AWS Chatbot (unique name for the secrets encryption stack)
resource "aws_iam_role" "chatbot" {
  name = "aws-config-secrets-chatbot-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "chatbot.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach ReadOnlyAccess policy to the Chatbot role to show resource details in Slack
resource "aws_iam_role_policy_attachment" "chatbot_read_only" {
  role       = aws_iam_role.chatbot.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# 7. AWS Chatbot Slack Channel Configuration linked to our custom SNS topic
resource "aws_chatbot_slack_channel_configuration" "slack" {
  configuration_name = "eks-secrets-encryption-alerts"
  iam_role_arn       = aws_iam_role.chatbot.arn
  logging_level      = "INFO"
  
  sns_topic_arns = [
    aws_sns_topic.compliance_alerts.arn
  ]

  slack_team_id    = var.slack_team_id
  slack_channel_id = var.slack_channel_id
}
