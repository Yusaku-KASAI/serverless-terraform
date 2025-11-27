locals {
  lambda_dlq_and_destinations = compact([
    var.dlq_arn,
    var.destination_on_failure_arn,
    var.destination_on_success_arn,
  ])

  # SQS の ARN だけ抽出
  lambda_destinations_sqs = [
    for arn in local.lambda_dlq_and_destinations : arn
    if length(regexall(":sqs:", arn)) > 0
  ]

  # SNS の ARN だけ抽出
  lambda_destinations_sns = [
    for arn in local.lambda_dlq_and_destinations : arn
    if length(regexall(":sns:", arn)) > 0
  ]
}

data "aws_iam_policy_document" "lambda_dlq_and_destinations" {
  count = length(local.lambda_dlq_and_destinations) > 0 ? 1 : 0

  # --- SQS 用権限 ---
  dynamic "statement" {
    for_each = length(local.lambda_destinations_sqs) > 0 ? [1] : []
    content {
      effect = "Allow"

      actions = [
        "sqs:SendMessage",
      ]

      resources = local.lambda_destinations_sqs
    }
  }

  # --- SNS 用権限 ---
  dynamic "statement" {
    for_each = length(local.lambda_destinations_sns) > 0 ? [1] : []
    content {
      effect = "Allow"

      actions = [
        "sns:Publish",
      ]

      resources = local.lambda_destinations_sns
    }
  }
}

resource "aws_iam_policy" "lambda_dlq_and_destinations" {
  count  = length(local.lambda_dlq_and_destinations) > 0 ? 1 : 0
  name   = "${var.function_name}-dlq-and-destinations"
  policy = data.aws_iam_policy_document.lambda_dlq_and_destinations[0].json
}

resource "aws_iam_role_policy_attachment" "lambda_dlq_and_destinations" {
  count      = length(aws_iam_policy.lambda_dlq_and_destinations) > 0 ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.lambda_dlq_and_destinations[0].arn
}
