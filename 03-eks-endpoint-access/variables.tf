variable "alert_email" {
  type        = string
  description = "Email address to receive compliance alerts"
  default     = "your-email@example.com"
}

variable "slack_team_id" {
  type        = string
  description = "The Slack Team/Workspace ID for AWS Chatbot (e.g., T0123456789)"
  default     = "T0000000000"
}

variable "slack_channel_id" {
  type        = string
  description = "The Slack Channel ID where AWS Chatbot will post messages (e.g., C0123456789)"
  default     = "C0000000000"
}
