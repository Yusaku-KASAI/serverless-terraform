locals {
  project = "serverless-terraform"
  basic_tags = {
    Project     = local.project
    Environment = "production"
    ManagedBy   = "Terraform"
  }

  lambda_first = {
    function_name       = "${local.project}-lambda_first"
    ecr_repository_name = "${local.project}-lambda_first"
  }

  lambda_second = {
    tags = merge(local.basic_tags, {
      LambdaFunction = "lambda_second"
    })

    function_name       = "${local.project}-lambda_second"
    description         = "Serverless Terraform Lambda Function（Full Specification）"
    ecr_repository_name = "${local.project}-lambda_second"
    image_tag           = "release"

    memory_mb       = 1024
    timeout_seconds = 25
    storage_mb      = 1024

    eventbridge_schedules = [
      {
        name                = "${local.project}-lambda_second-every-5min"
        schedule_expression = "rate(5 minutes)"
      },
      {
        name                = "${local.project}-lambda_second-daily-9am"
        schedule_expression = "cron(0 0 * * ? *)"
      }
    ]

    log_retention_days         = 14
    error_alarm_threshold      = 3
    throttle_alarm_threshold   = 3
    memory_alarm_threshold     = 20
    duration_alarm_threshold   = 100
    invocation_alarm_threshold = 5
  }

  slack = {
    channel1 = {
      team_id    = var.slack_team_id    # Slack ワークスペース ID
      channel_id = var.slack_channel_id # 通知先 Slack チャンネル ID
    }
  }
}
