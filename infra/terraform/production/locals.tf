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

    memory_mb                      = 1024
    timeout_seconds                = 25
    storage_mb                     = 1024
    reserved_concurrent_executions = 1

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

  apigateway_first = {
    name        = "${local.project}-apigateway_first"
    domain_name = var.apigateway_first_domain_name

    lambda_proxy_methods = {
      all = {
        path               = "/{proxy+}"
        http_method        = "ANY"
        lambda_module_name = "lambda_first"
      }
    }
  }

  apigateway_second = {
    tags = merge(local.basic_tags, {
      ApiGateway = "apigateway_second"
    })

    name        = "${local.project}-apigateway_second"
    stage_name  = "production"
    domain_name = var.apigateway_second_domain_name

    enable_api_key = true
    usage_plan_throttle = {
      rate_limit  = 50
      burst_limit = 20
    }
    usage_plan_quota = {
      limit  = 100000
      period = "MONTH"
    }

    access_log_retention_in_days    = 30
    execution_log_retention_in_days = 30

    stage_alarm_config = {
      five_xx_error_threshold = 1
      # four_xx_error_threshold = 5
      latency_threshold_ms = 1000
      count_threshold      = 10
    }

    lambda_proxy_methods = {
      v1hello = {
        path               = "/v1/hello"
        http_method        = "GET"
        lambda_module_name = "lambda_second"
      }
      v1proxy = {
        path               = "/v1/{proxy+}"
        http_method        = "ANY"
        lambda_module_name = "lambda_second"
        api_key_required   = true
      }
    }

    sqs_methods = {
      v1enqueue = {
        path             = "/v1/enqueue"
        http_method      = "POST"
        sqs_data_name    = "sqs_main"
        api_key_required = true

        # aws_api_gateway_method 用
        request_parameters = {
          "method.request.header.Content-Type" = true
        }
        request_models = {}

        # aws_api_gateway_integration 用（SendMessage の典型パターン）
        integration_http_method = "POST"
        request_parameters_mapping = {
          "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
        }
        request_templates_mapping = {
          "application/json" = "Action=SendMessage&MessageBody=$util.urlEncode($input.body)"
        }

        # レスポンス
        responses = [
          {
            status_code       = "200"
            selection_pattern = "" # デフォルトレスポンスにする

            # content-type => モデル名（今回はモデル未使用）
            response_models = {}

            # Integration Response → Method Response のヘッダマッピング
            response_parameters_mapping = {
              "method.response.header.Content-Type" = "'application/json'"
            }

            # content-type => テンプレート
            response_templates_mapping = {
              "application/json" = "{ \"message\": \"Message enqueued successfully.\" }"
            }
          }
        ]

        # モデル定義（今回は使わないので空）
        response_models = {}
      }
      v2enqueue = {
        path             = "/v2/enqueue"
        http_method      = "GET"
        sqs_data_name    = "sqs_second"
        api_key_required = false

        # aws_api_gateway_method 用
        request_parameters = {}
        request_models     = {}

        # aws_api_gateway_integration 用（SendMessage の典型パターン）
        integration_http_method = "GET"
        request_parameters_mapping = {
          "integration.request.querystring.Action"      = "'SendMessage'"
          "integration.request.querystring.MessageBody" = "'Hello from API Gateway v2enqueue method'"
          "integration.request.querystring.Version"     = "'2012-11-05'"
        }
        request_templates_mapping = {}

        # レスポンス（例: 302 のリダイレクトを返す）
        responses = [
          {
            status_code       = "302"
            selection_pattern = "" # デフォルトレスポンスにする

            # content-type => モデル名（今回はモデル未使用）
            response_models = {}

            # Integration Response → Method Response のヘッダマッピング
            response_parameters_mapping = {
              "method.response.header.Location" = "'https://line.me'"
            }

            # content-type => テンプレート
            response_templates_mapping = {}
          }
        ]

        # モデル定義（今回は使わないので空）
        response_models = {}
      }
    }
  }

  slack = {
    channel1 = {
      team_id    = var.slack_team_id    # Slack ワークスペース ID
      channel_id = var.slack_channel_id # 通知先 Slack チャンネル ID
    }
  }
}
