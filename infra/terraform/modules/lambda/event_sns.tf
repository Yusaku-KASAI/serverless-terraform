resource "aws_sns_topic_subscription" "sns_lambda" {
  for_each = { for s in var.sns_event_sources : s.name => s }

  topic_arn = each.value.topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.this.arn

  depends_on = [aws_lambda_permission.from_sns]
}

resource "aws_lambda_permission" "from_sns" {
  for_each = { for s in var.sns_event_sources : s.name => s }

  statement_id  = "AllowExecutionFromSNS-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = each.value.topic_arn
}
