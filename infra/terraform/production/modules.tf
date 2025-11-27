module "lambda_first" {
  source = "../modules/lambda"

  project = local.project

  function_name       = local.lambda_first.function_name
  ecr_repository_name = local.lambda_first.ecr_repository_name
}

module "lambda_second" {
  source = "../modules/lambda"

  project = local.project
  tags    = local.lambda_second.tags

  function_name       = local.lambda_second.function_name
  description         = local.lambda_second.description
  extra_policy_arns   = []
  ecr_repository_name = local.lambda_second.ecr_repository_name
  image_tag           = local.lambda_second.image_tag

  timeout               = local.lambda_second.timeout_seconds
  memory_size           = local.lambda_second.memory_mb
  storage_size          = local.lambda_second.storage_mb
  environment_variables = local.lambda_environments.lambda_second

  use_vpc            = local.flags.lambda_second.use_vpc
  subnet_ids         = var.lambda_subnet_ids
  security_group_ids = var.lambda_security_group_ids

  dlq_arn                    = var.dlq_arn
  destination_on_failure_arn = var.failure_queue_arn
  destination_on_success_arn = var.success_queue_arn

  eventbridge_schedules = local.lambda_second.eventbridge_schedules
  sqs_event_sources = [
    {
      name       = "main-queue"
      queue_arn  = var.queue_main_arn
      batch_size = 10
    },
    {
      name       = "second-queue"
      queue_arn  = var.queue_second_arn
      batch_size = 5
    }
  ]
  sns_event_sources = [
    {
      name      = "main-topic"
      topic_arn = var.sns_topic_main_arn
    }
  ]

  log_retention_in_days      = local.lambda_second.log_retention_days
  error_alarm_threshold      = local.lambda_second.error_alarm_threshold
  throttle_alarm_threshold   = local.lambda_second.throttle_alarm_threshold
  memory_alarm_threshold     = local.lambda_second.memory_alarm_threshold
  duration_alarm_threshold   = local.lambda_second.duration_alarm_threshold
  invocation_alarm_threshold = local.lambda_second.invocation_alarm_threshold
  use_xray                   = local.flags.lambda_second.use_xray
}

module "chatbot_channel1" {
  source = "../modules/chatbot"

  project          = local.project
  slack_team_id    = local.slack.channel1.team_id
  slack_channel_id = local.slack.channel1.channel_id
  sns_topic_arns = [
    module.lambda_first.alarm_sns_topic_arn,
  ]
}
