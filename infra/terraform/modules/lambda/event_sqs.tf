resource "aws_lambda_event_source_mapping" "sqs" {
  for_each = { for s in var.sqs_event_sources : s.name => s }

  event_source_arn = each.value.queue_arn
  function_name    = aws_lambda_function.this.arn

  batch_size                         = lookup(each.value, "batch_size", 10)
  maximum_batching_window_in_seconds = lookup(each.value, "maximum_batching_window_second", 0)

  depends_on = [aws_iam_role_policy_attachment.lambda_sqs]
}

data "aws_iam_policy_document" "lambda_sqs" {
  count = length(var.sqs_event_sources) > 0 ? 1 : 0

  statement {
    effect = "Allow"

    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ChangeMessageVisibility",
    ]

    resources = [for s in var.sqs_event_sources : s.queue_arn]
  }
}

resource "aws_iam_policy" "lambda_sqs" {
  count = length(var.sqs_event_sources) > 0 ? 1 : 0

  name   = "${var.function_name}-sqs-access"
  policy = data.aws_iam_policy_document.lambda_sqs[0].json
}

resource "aws_iam_role_policy_attachment" "lambda_sqs" {
  count = length(var.sqs_event_sources) > 0 ? 1 : 0

  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.lambda_sqs[0].arn
}
