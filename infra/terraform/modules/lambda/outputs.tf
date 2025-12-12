# ------------------------------------------------------------
# Lambda 基本情報
# ------------------------------------------------------------
output "function_name" {
  description = "Lambda 関数名"
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "Lambda 関数 ARN"
  value       = aws_lambda_function.this.arn
}

output "function_qualified_arn" {
  description = "最新バージョンに紐づく Lambda の qualified ARN（バージョン付き ARN）"
  value       = aws_lambda_function.this.qualified_arn
}

output "function_version" {
  description = "最新の Lambda バージョン番号"
  value       = aws_lambda_function.this.version
}

# ------------------------------------------------------------
# IAM
# ------------------------------------------------------------
output "role_arn" {
  description = "Lambda 実行ロール ARN"
  value       = aws_iam_role.this.arn
}

# ------------------------------------------------------------
# CloudWatch Logs
# ------------------------------------------------------------
output "log_group_name" {
  description = "CloudWatch Logs のロググループ名"
  value       = aws_cloudwatch_log_group.this.name
}

# ------------------------------------------------------------
# ECR
# ------------------------------------------------------------
output "ecr_repository_url" {
  description = "ECR リポジトリ URL"
  value       = aws_ecr_repository.this.repository_url
}

output "ecr_repository_arn" {
  description = "ECR リポジトリ ARN"
  value       = aws_ecr_repository.this.arn
}

# ------------------------------------------------------------
# アラーム / SNS
# ------------------------------------------------------------
output "alarm_sns_topic_arn" {
  description = "Lambda アラーム通知用 SNS Topic ARN"
  value       = aws_sns_topic.alarm.arn
}

output "cloudwatch_alarm_arns" {
  description = "Lambda に紐づく CloudWatch Metric Alarm ARNs 一式"
  value = {
    error      = aws_cloudwatch_metric_alarm.error.arn
    throttle   = aws_cloudwatch_metric_alarm.throttle.arn
    memory     = aws_cloudwatch_metric_alarm.memory.arn
    duration   = aws_cloudwatch_metric_alarm.duration.arn
    invocation = length(aws_cloudwatch_metric_alarm.invocation) > 0 ? aws_cloudwatch_metric_alarm.invocation[0].arn : null
  }
}

# ------------------------------------------------------------
# イベントソース
# ------------------------------------------------------------
output "eventbridge_rule_arns" {
  description = "EventBridge スケジュールルール ARN のマップ（name => arn）"
  value       = { for name, rule in aws_cloudwatch_event_rule.schedule : name => rule.arn }
}

output "sns_subscription_arns" {
  description = "SNS → Lambda サブスクリプション ARN のマップ（name => arn）"
  value       = { for name, sub in aws_sns_topic_subscription.sns_lambda : name => sub.arn }
}

output "sqs_event_source_mapping_uuids" {
  description = "SQS イベントソースマッピング UUID のマップ（name => uuid）"
  value       = { for name, m in aws_lambda_event_source_mapping.sqs : name => m.uuid }
}
