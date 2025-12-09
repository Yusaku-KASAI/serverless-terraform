resource "aws_api_gateway_method" "this" {
  rest_api_id      = var.rest_api_id
  resource_id      = var.resource_id
  http_method      = var.http_method
  authorization    = "NONE" # COGNITO使いたくなったら要検討
  api_key_required = var.api_key_required
  request_models = length(var.request_models) > 0 ? {
    for name, m in aws_api_gateway_model.request_models :
    m.content_type => m.name
  } : null
  request_parameters = length(var.request_parameters) > 0 ? var.request_parameters : null
}

resource "aws_api_gateway_integration" "this" {
  rest_api_id             = var.rest_api_id
  resource_id             = var.resource_id
  http_method             = aws_api_gateway_method.this.http_method
  type                    = "AWS"
  integration_http_method = var.integration_http_method
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:sqs:path/${data.aws_caller_identity.self.account_id}/${var.queue_name}"
  credentials             = aws_iam_role.apigw_sqs_role.arn
  timeout_milliseconds    = 29000 # （上限値）サービスクオータで上限引き上げ可能
  request_parameters      = length(var.request_parameters_mapping) > 0 ? var.request_parameters_mapping : null
  request_templates       = length(var.request_templates_mapping) > 0 ? var.request_templates_mapping : null
  passthrough_behavior    = length(var.request_templates_mapping) > 0 ? "WHEN_NO_TEMPLATES" : null

  depends_on = [aws_api_gateway_method.this]
}

# responses から method_response と integration_response を生成し、1対1対応させる(このモジュールでの追加制約)
locals {
  responses_by_code = {
    for r in var.responses :
    r.status_code => r
  }
}

resource "aws_api_gateway_method_response" "this" {
  for_each = local.responses_by_code

  rest_api_id = var.rest_api_id
  resource_id = var.resource_id
  http_method = aws_api_gateway_method.this.http_method
  status_code = each.value.status_code

  response_parameters = length(each.value.response_parameters_mapping) > 0 ? {
    # mapping 側で指定があれば全部 true
    for k, v in each.value.response_parameters_mapping :
    k => true
  } : null

  response_models = length(each.value.response_models) > 0 ? {
    for k, v in each.value.response_models :
    k => aws_api_gateway_model.response_models[v].name
  } : null

  depends_on = [aws_api_gateway_method.this]
}

resource "aws_api_gateway_integration_response" "this" {
  for_each = local.responses_by_code

  rest_api_id = var.rest_api_id
  resource_id = var.resource_id
  http_method = aws_api_gateway_method.this.http_method
  status_code = each.value.status_code

  # selection_pattern が空なら設定しない(デフォルトになる)
  selection_pattern = each.value.selection_pattern != "" ? each.value.selection_pattern : null

  response_parameters = length(each.value.response_parameters_mapping) > 0 ? each.value.response_parameters_mapping : null
  response_templates  = length(each.value.response_templates_mapping) > 0 ? each.value.response_templates_mapping : null

  depends_on = [aws_api_gateway_integration.this]
}

resource "aws_api_gateway_model" "request_models" {
  for_each = var.request_models

  rest_api_id  = var.rest_api_id
  name         = each.key
  content_type = each.key
  schema       = each.value
}

resource "aws_api_gateway_model" "response_models" {
  for_each = var.response_models

  rest_api_id  = var.rest_api_id
  name         = each.key
  content_type = each.value.content_type
  schema       = each.value.schema
}
