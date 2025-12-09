data "aws_iam_policy_document" "apigw_sqs_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "apigw_sqs_role" {
  name               = "apigw-sqs-role-${var.http_method}-${var.resource_id}-${var.queue_name}"
  assume_role_policy = data.aws_iam_policy_document.apigw_sqs_assume.json
}

data "aws_iam_policy_document" "apigw_sqs_policy" {
  statement {
    actions   = ["sqs:SendMessage"]
    resources = [var.queue_arn]
  }
}

resource "aws_iam_role_policy" "apigw_sqs" {
  name   = "apigw-sqs-policy-${var.http_method}-${var.resource_id}-${var.queue_name}"
  role   = aws_iam_role.apigw_sqs_role.id
  policy = data.aws_iam_policy_document.apigw_sqs_policy.json
}
