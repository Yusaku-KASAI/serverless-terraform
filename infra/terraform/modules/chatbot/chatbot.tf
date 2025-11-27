resource "aws_chatbot_slack_channel_configuration" "this" {
  configuration_name = local.configuration_name

  iam_role_arn          = aws_iam_role.chatbot_slack_role.arn
  guardrail_policy_arns = [aws_iam_policy.chatbot_slack_deny_all.arn]

  slack_team_id    = var.slack_team_id
  slack_channel_id = var.slack_channel_id

  sns_topic_arns = var.sns_topic_arns

  tags = merge(var.tags, {
    Name = local.configuration_name
  })
}
