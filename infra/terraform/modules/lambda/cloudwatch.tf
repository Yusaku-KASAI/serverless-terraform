resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_in_days
}

resource "aws_cloudwatch_log_metric_filter" "memory_size" {
  name           = "${var.function_name}MemorySizeMetricFilter"
  log_group_name = aws_cloudwatch_log_group.this.name
  pattern        = "{ $.type = \"platform.report\" && $.record.metrics.memorySizeMB = \"*\" }"

  metric_transformation {
    name      = "MemorySize"
    namespace = "LambdaCustomMetrics/${var.function_name}"
    value     = "$.record.metrics.memorySizeMB"
  }
}

resource "aws_cloudwatch_log_metric_filter" "max_memory_used" {
  name           = "${var.function_name}MaxMemoryUsedMetricFilter"
  log_group_name = aws_cloudwatch_log_group.this.name
  pattern        = "{ $.type = \"platform.report\" && $.record.metrics.maxMemoryUsedMB = \"*\" }"

  metric_transformation {
    name      = "MaxMemoryUsed"
    namespace = "LambdaCustomMetrics/${var.function_name}"
    value     = "$.record.metrics.maxMemoryUsedMB"
  }
}

# Error アラーム
resource "aws_cloudwatch_metric_alarm" "error" {
  alarm_name          = "${aws_lambda_function.this.function_name}-errors"
  alarm_description   = "Alarm when the error(include timeout and out of memory) count in 1 minute exceeds ${var.error_alarm_threshold} in the last 3 minutes"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 1
  threshold           = var.error_alarm_threshold

  metric_name = "Errors"
  namespace   = "AWS/Lambda"
  period      = 60
  statistic   = "Sum"

  dimensions = {
    FunctionName = aws_lambda_function.this.function_name
  }

  alarm_actions = [aws_sns_topic.alarm.arn]
}

# Throttle アラーム
resource "aws_cloudwatch_metric_alarm" "throttle" {
  alarm_name          = "${aws_lambda_function.this.function_name}-throttles"
  alarm_description   = "Alarm when the throttled count in 1 minute exceeds ${var.throttle_alarm_threshold} in the last 3 minutes"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 1
  threshold           = var.throttle_alarm_threshold

  metric_name = "Throttles"
  namespace   = "AWS/Lambda"
  period      = 60
  statistic   = "Sum"

  dimensions = {
    FunctionName = aws_lambda_function.this.function_name
  }

  alarm_actions = [aws_sns_topic.alarm.arn]
}

# Memory 使用率アラーム (Metric Math)
resource "aws_cloudwatch_metric_alarm" "memory" {
  alarm_name          = "${aws_lambda_function.this.function_name}-memory-usage"
  alarm_description   = "Alarm when the memory usage exceeds ${var.memory_alarm_threshold} % of the allocated memory in the last 15 minutes"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 1
  threshold           = var.memory_alarm_threshold

  alarm_actions = [aws_sns_topic.alarm.arn]

  metric_query {
    id          = "e1"
    expression  = "100 * m1 / m2"
    label       = "MemoryUsageRatio"
    return_data = true
  }

  metric_query {
    id          = "m1"
    label       = "MaxMemoryUsed"
    return_data = false

    metric {
      namespace   = "LambdaCustomMetrics/${var.function_name}"
      metric_name = "MaxMemoryUsed"
      period      = 300
      stat        = "Maximum"
    }
  }

  # 運用時にMemorySizeは固定であることに注意
  metric_query {
    id          = "m2"
    label       = "MemorySize"
    return_data = false

    metric {
      namespace   = "LambdaCustomMetrics/${var.function_name}"
      metric_name = "MemorySize"
      period      = 300
      stat        = "Maximum"
    }
  }
}


# Duration アラーム
resource "aws_cloudwatch_metric_alarm" "duration" {
  alarm_name          = "${aws_lambda_function.this.function_name}-duration"
  alarm_description   = "Alarm when the duration exceeds ${var.duration_alarm_threshold} ms in the last 15 minutes"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 1
  threshold           = var.duration_alarm_threshold

  metric_name = "Duration"
  namespace   = "AWS/Lambda"
  period      = 300 # 5 minutes
  statistic   = "Maximum"

  dimensions = {
    FunctionName = aws_lambda_function.this.function_name
  }

  alarm_actions = [aws_sns_topic.alarm.arn]
}


resource "aws_cloudwatch_metric_alarm" "invocation" {
  alarm_name          = "${aws_lambda_function.this.function_name}-invocations"
  alarm_description   = "Alarm when the invocation count in 5 minute exceeds ${var.invocation_alarm_threshold} in the last 15 minutes"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 1
  threshold           = var.invocation_alarm_threshold

  metric_name = "Invocations"
  namespace   = "AWS/Lambda"
  period      = 300
  statistic   = "Sum"

  dimensions = {
    FunctionName = aws_lambda_function.this.function_name
  }

  alarm_actions = [aws_sns_topic.alarm.arn]
}


resource "aws_sns_topic" "alarm" {
  name         = "${aws_lambda_function.this.function_name}-alarm-topic"
  display_name = "${aws_lambda_function.this.function_name} Alarm"

  tags = merge(var.tags, {
    Name = "${aws_lambda_function.this.function_name}-alarm-topic"
  })
}
