# API Gateway から CloudWatch Logs へ書き込むための IAM Role
data "aws_iam_policy_document" "apigw_cloudwatch_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "apigw_cloudwatch_role" {
  name               = "${var.name}-apigw-cloudwatch-role"
  assume_role_policy = data.aws_iam_policy_document.apigw_cloudwatch_assume.json
}

data "aws_iam_policy_document" "apigw_cloudwatch_policy" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
      "logs:GetLogEvents",
      "logs:FilterLogEvents"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "apigw_cloudwatch" {
  name   = "${var.name}-apigw-cloudwatch"
  role   = aws_iam_role.apigw_cloudwatch_role.id
  policy = data.aws_iam_policy_document.apigw_cloudwatch_policy.json
}

# API Gateway 全体設定に CloudWatch ロールを紐付け
resource "aws_api_gateway_account" "this" {
  count = var.manage_apigw_account_logging_role ? 1 : 0

  cloudwatch_role_arn = aws_iam_role.apigw_cloudwatch_role.arn
}

# API Gateway のリソースポリシー（ip制限用）
locals {
  rp_enabled = length(var.allowed_source_ips) > 0 || length(var.denied_source_ips) > 0
  has_allow  = length(var.allowed_source_ips) > 0
  has_deny   = length(var.denied_source_ips) > 0

  # execute-api の ARN（REST API 全体に適用したいので /*/*/* で OK）
  execute_api_arn = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.self.account_id}:${aws_api_gateway_rest_api.this.id}/*/*/*"
}

data "aws_iam_policy_document" "apigw_resource_policy" {
  count = local.rp_enabled ? 1 : 0

  # 1) denylist（優先）
  dynamic "statement" {
    for_each = local.has_deny ? [1] : []
    content {
      sid    = "DenyBySourceIpDenyList"
      effect = "Deny"

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      actions   = ["execute-api:Invoke"]
      resources = [local.execute_api_arn]

      condition {
        test     = "IpAddress"
        variable = "aws:SourceIp"
        values   = var.denied_source_ips
      }
    }
  }

  # 2) allowlist がある場合：allow に含まれないものを Deny
  dynamic "statement" {
    for_each = local.has_allow ? [1] : []
    content {
      sid    = "DenyBySourceIpNotInAllowList"
      effect = "Deny"

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      actions   = ["execute-api:Invoke"]
      resources = [local.execute_api_arn]

      condition {
        test     = "NotIpAddress"
        variable = "aws:SourceIp"
        values   = var.allowed_source_ips
      }
    }
  }

  # 3) 明示 allow（保険：ポリシーの意図が分かりやすくなる）
  statement {
    sid    = "AllowInvoke"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["execute-api:Invoke"]
    resources = [local.execute_api_arn]
  }
}
