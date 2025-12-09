###################################
# Deployment
###################################
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  description = "Deployment for ${var.stage_name}"

  # メソッド定義が変わったときに再デプロイさせるトリガ
  triggers = {
    redeploy = sha1(jsonencode({
      lambda_proxy_methods = var.lambda_proxy_methods
      sqs_methods          = var.sqs_methods
    }))
  }

  lifecycle {
    create_before_destroy = true
  }

  # サブモジュールの Method/Integration に依存させる
  depends_on = [
    module.lambda_proxy_methods,
    module.sqs_methods,
  ]
}

###################################
# Stage
###################################
resource "aws_api_gateway_stage" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  stage_name    = var.stage_name
  deployment_id = aws_api_gateway_deployment.this.id
  description   = "Stage for ${var.stage_name}"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access_logs.arn
    format = jsonencode({
      requestId       = "$context.requestId"
      requestTime     = "$context.requestTime"
      ip              = "$context.identity.sourceIp"
      caller          = "$context.identity.caller"
      user            = "$context.identity.user"
      httpMethod      = "$context.httpMethod"
      resourcePath    = "$context.resourcePath"
      path            = "$context.path"
      status          = "$context.status"
      responseLatency = "$context.responseLatency"
      protocol        = "$context.protocol"
      responseLength  = "$context.responseLength"
    })
  }

  tags = merge(var.tags, {
    Name = "${var.name}-${var.stage_name}"
    }
  )
}

resource "aws_api_gateway_method_settings" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name

  method_path = "*/*" # 全メソッド対象

  settings {
    metrics_enabled    = true
    logging_level      = "INFO"
    data_trace_enabled = true
    # メソッドレベルでは制限しない（一般公開なら制限してもあまり意味なさそう）
    # throttling_burst_limit = var.method_settings.throttling_burst_limit
    # throttling_rate_limit  = var.method_settings.throttling_rate_limit
  }
}

###################################
# API Key & Usage Plan
###################################

resource "aws_api_gateway_api_key" "this" {
  count = var.enable_api_key ? 1 : 0

  name        = "${var.name}-api-key"
  description = "API key for ${var.name}"
  enabled     = true

  tags = merge(var.tags, {
    Name = "${var.name}-api-key"
    }
  )
}

resource "aws_api_gateway_usage_plan" "this" {
  name        = "${var.name}-usage-plan"
  description = "Usage plan for ${var.name}"

  api_stages {
    api_id = aws_api_gateway_rest_api.this.id
    stage  = aws_api_gateway_stage.this.stage_name

    # ここでもクライアント別かつステージ別かつメソッド別での制限が可能だが単純化のため省略
    # 制限する場合の値は全体で固定して、メソッドごとではAPIキーの有効化/無効化のみでコントロールする想定
  }

  dynamic "throttle_settings" {
    for_each = var.usage_plan_throttle.rate_limit != null && var.usage_plan_throttle.burst_limit != null ? [1] : []

    content {
      rate_limit  = var.usage_plan_throttle.rate_limit
      burst_limit = var.usage_plan_throttle.burst_limit
    }
  }

  dynamic "quota_settings" {
    for_each = var.usage_plan_quota.limit != null && var.usage_plan_quota.period != null ? [1] : []

    content {
      limit  = var.usage_plan_quota.limit
      period = var.usage_plan_quota.period
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name}-usage-plan"
    }
  )
}

resource "aws_api_gateway_usage_plan_key" "this" {
  count = var.enable_api_key ? 1 : 0

  key_id        = aws_api_gateway_api_key.this[0].id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.this.id
}
