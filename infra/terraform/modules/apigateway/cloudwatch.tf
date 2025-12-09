############################
# CloudWatch Logs (アクセスログ用)
############################

resource "aws_cloudwatch_log_group" "access_logs" {
  name              = "/apigw/${var.name}/access"
  retention_in_days = var.access_log_retention_in_days
}

############################
# CloudWatch Logs (実行ログ用)
############################

resource "aws_cloudwatch_log_group" "execution_logs" {
  name              = "API-Gateway-Execution-Logs_${aws_api_gateway_rest_api.this.id}/${var.stage_name}"
  retention_in_days = var.execution_log_retention_in_days
}

############################
# CloudWatch Alarms (監視用)
############################

resource "aws_cloudwatch_metric_alarm" "apigw_stage_5xx" {
  count = var.stage_alarm_config.five_xx_error_threshold != null ? 1 : 0

  alarm_name          = "${var.name}-${var.stage_name}-5xx-errors"
  alarm_description   = "5XXError count >= ${var.stage_alarm_config.five_xx_error_threshold} in any 5-minute period (period=300s). Evaluates 3 consecutive periods (3×5min = 15min) and requires 1 datapoint to alarm."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 1
  threshold           = var.stage_alarm_config.five_xx_error_threshold

  metric_name = "5XXError"
  namespace   = "AWS/ApiGateway"
  period      = 300
  statistic   = "Sum"

  dimensions = {
    ApiName = aws_api_gateway_rest_api.this.name
    Stage   = var.stage_name
  }

  alarm_actions = [aws_sns_topic.alarm.arn]
}


resource "aws_cloudwatch_metric_alarm" "apigw_stage_4xx" {
  count = var.stage_alarm_config.four_xx_error_threshold != null ? 1 : 0

  alarm_name          = "${var.name}-${var.stage_name}-4xx-errors"
  alarm_description   = "4XXError count >= ${var.stage_alarm_config.four_xx_error_threshold} in any 5-minute period (period=300s). Evaluates 3 consecutive periods (3×5min = 15min) and requires 1 datapoint to alarm."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 1
  threshold           = var.stage_alarm_config.four_xx_error_threshold

  metric_name = "4XXError"
  namespace   = "AWS/ApiGateway"
  period      = 300
  statistic   = "Sum"

  dimensions = {
    ApiName = aws_api_gateway_rest_api.this.name
    Stage   = var.stage_name
  }

  alarm_actions = [aws_sns_topic.alarm.arn]
}

resource "aws_cloudwatch_metric_alarm" "apigw_stage_latency" {
  count = var.stage_alarm_config.latency_threshold_ms != null ? 1 : 0

  alarm_name          = "${var.name}-${var.stage_name}-latency"
  alarm_description   = "Maximum Latency >= ${var.stage_alarm_config.latency_threshold_ms} ms in any 5-minute period (period=300s). Evaluates 3 consecutive periods (3×5min = 15min) and requires 1 datapoint to alarm."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 1
  threshold           = var.stage_alarm_config.latency_threshold_ms

  metric_name = "Latency"
  namespace   = "AWS/ApiGateway"
  period      = 300
  statistic   = "Maximum"

  dimensions = {
    ApiName = aws_api_gateway_rest_api.this.name
    Stage   = var.stage_name
  }

  alarm_actions = [aws_sns_topic.alarm.arn]
}

resource "aws_cloudwatch_metric_alarm" "apigw_stage_count" {
  count = var.stage_alarm_config.count_threshold != null ? 1 : 0

  alarm_name          = "${var.name}-${var.stage_name}-request-count"
  alarm_description   = "Request Count >= ${var.stage_alarm_config.count_threshold} in any 5-minute period (period=300s). Evaluates 3 consecutive periods (3×5min = 15min) and requires 1 datapoint to alarm."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 1
  threshold           = var.stage_alarm_config.count_threshold

  metric_name = "Count"
  namespace   = "AWS/ApiGateway"
  period      = 300
  statistic   = "Sum"

  dimensions = {
    ApiName = aws_api_gateway_rest_api.this.name
    Stage   = var.stage_name
  }

  alarm_actions = [aws_sns_topic.alarm.arn]
}

resource "aws_sns_topic" "alarm" {
  name         = "${var.name}-alarm-topic"
  display_name = "${var.name} Alarm"

  tags = merge(var.tags, {
    Name = "${var.name}-alarm-topic"
  })
}
