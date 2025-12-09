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
