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

  timeout                        = local.lambda_second.timeout_seconds
  memory_size                    = local.lambda_second.memory_mb
  storage_size                   = local.lambda_second.storage_mb
  environment_variables          = local.lambda_environments.lambda_second
  reserved_concurrent_executions = local.lambda_second.reserved_concurrent_executions

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

# あんまり良くないかもだけどmoduleで綺麗に参照したいので
locals {
  # Lambda モジュール名 -> function_arn のマップ
  lambda_function_arns = {
    lambda_first  = module.lambda_first.function_arn
    lambda_second = module.lambda_second.function_arn
  }

  # SQS モジュール名 -> { arn, name } のマップ
  sqs_queues = {
    sqs_main = {
      arn  = data.aws_sqs_queue.sqs_main.arn
      name = data.aws_sqs_queue.sqs_main.name
    }
    sqs_second = {
      arn  = data.aws_sqs_queue.sqs_second.arn
      name = data.aws_sqs_queue.sqs_second.name
    }
  }
}

module "apigateway_first" {
  source = "../modules/apigateway"

  project = local.project
  name    = local.apigateway_first.name

  lambda_proxy_methods = [
    for method_key, method_val in local.apigateway_first.lambda_proxy_methods :
    {
      path        = method_val.path
      http_method = method_val.http_method
      lambda_arn  = local.lambda_function_arns[method_val.lambda_module_name]
    }
  ]

  enable_custom_domain = local.flags.apigateway_first.enable_custom_domain
  domain_name          = local.apigateway_first.domain_name
  acm_certificate_arn  = var.apigateway_first_acm_arn
  zone_id              = var.host_zone_id
}

module "apigateway_second" {
  source = "../modules/apigateway"

  project = local.project
  tags    = local.apigateway_second.tags

  name       = local.apigateway_second.name
  stage_name = local.apigateway_second.stage_name

  enable_api_key      = local.apigateway_second.enable_api_key
  usage_plan_throttle = local.apigateway_second.usage_plan_throttle
  usage_plan_quota    = local.apigateway_second.usage_plan_quota

  enable_custom_domain = local.flags.apigateway_second.enable_custom_domain
  domain_name          = local.apigateway_second.domain_name
  acm_certificate_arn  = var.apigateway_second_acm_arn
  zone_id              = var.host_zone_id

  access_log_retention_in_days    = local.apigateway_second.access_log_retention_in_days
  execution_log_retention_in_days = local.apigateway_second.execution_log_retention_in_days
  use_xray                        = local.flags.apigateway_second.use_xray
  stage_alarm_config              = local.apigateway_second.stage_alarm_config

  lambda_proxy_methods = [
    for method_key, method_val in local.apigateway_second.lambda_proxy_methods :
    merge(
      { for k, v in method_val : k => v if k != "lambda_module_name" },
      { lambda_arn = local.lambda_function_arns[method_val.lambda_module_name] }
    )
  ]

  sqs_methods = [
    for method_key, method_val in local.apigateway_second.sqs_methods :
    merge(
      { for k, v in method_val : k => v if k != "sqs_data_name" },
      { queue_arn = local.sqs_queues[method_val.sqs_data_name].arn, queue_name = local.sqs_queues[method_val.sqs_data_name].name }
    )
  ]
}

module "chatbot_channel1" {
  source = "../modules/chatbot"

  project          = local.project
  slack_team_id    = local.slack.channel1.team_id
  slack_channel_id = local.slack.channel1.channel_id
  sns_topic_arns = [
    module.lambda_first.alarm_sns_topic_arn,
    module.lambda_second.alarm_sns_topic_arn,
    module.apigateway_second.alarm_sns_topic_arn,
  ]
}
