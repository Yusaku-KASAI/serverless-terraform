output "configuration_name" {
  description = "作成された Chatbot Slack channel configuration 名"
  value       = aws_chatbot_slack_channel_configuration.this.configuration_name
}

output "chatbot_slack_channel_arn" {
  description = "AWS Chatbot Slack channel configuration の ARN"
  value       = aws_chatbot_slack_channel_configuration.this.chat_configuration_arn
}

output "iam_role_arn" {
  description = "Chatbot が Assume する IAM Role の ARN"
  value       = aws_iam_role.chatbot_slack_role.arn
}

output "guardrail_policy_arn" {
  description = "Chatbot 用 guardrail(deny all) ポリシー ARN"
  value       = aws_iam_policy.chatbot_slack_deny_all.arn
}

output "slack_team_id" {
  description = "通知先 Slack Workspace ID"
  value       = aws_chatbot_slack_channel_configuration.this.slack_team_id
}

output "slack_channel_id" {
  description = "通知先 Slack Channel ID"
  value       = aws_chatbot_slack_channel_configuration.this.slack_channel_id
}

output "slack_team_name" {
  description = "通知先 Slack Workspace 名"
  value       = aws_chatbot_slack_channel_configuration.this.slack_team_name
}

output "slack_channel_name" {
  description = "通知先 Slack Channel 名"
  value       = aws_chatbot_slack_channel_configuration.this.slack_channel_name
}

output "sns_topic_arns" {
  description = "Chatbot に紐付けた SNS Topic の ARN 一覧"
  value       = aws_chatbot_slack_channel_configuration.this.sns_topic_arns
}
