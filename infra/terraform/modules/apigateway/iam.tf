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
  cloudwatch_role_arn = aws_iam_role.apigw_cloudwatch_role.arn
}
