resource "aws_cloudwatch_event_rule" "schedule" {
  for_each = { for s in var.eventbridge_schedules : s.name => s }

  name                = each.value.name
  schedule_expression = each.value.schedule_expression
}

resource "aws_cloudwatch_event_target" "schedule" {
  for_each = aws_cloudwatch_event_rule.schedule

  rule      = each.value.name
  target_id = "${each.value.name}-target"
  arn       = aws_lambda_function.this.arn

  depends_on = [aws_lambda_permission.from_eventbridge]
}

resource "aws_lambda_permission" "from_eventbridge" {
  for_each = aws_cloudwatch_event_rule.schedule

  statement_id  = "AllowExecutionFromEventBridge-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  source_arn    = each.value.arn
}
