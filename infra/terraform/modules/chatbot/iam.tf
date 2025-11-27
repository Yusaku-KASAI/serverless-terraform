resource "aws_iam_role" "chatbot_slack_role" {
  name = "${local.configuration_name}-role"

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

  tags = merge(var.tags, {
    Name = "${local.configuration_name}-role"
  })
}

# 今はslack chatbot で許可するアクションが無いため、全て拒否するポリシーをアタッチする（通知のみで利用）
resource "aws_iam_policy" "chatbot_slack_deny_all" {
  name = "${local.configuration_name}-deny-all-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Deny"
        Action   = "*"
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${local.configuration_name}-deny-all-policy"
  })
}
