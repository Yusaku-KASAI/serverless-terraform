resource "aws_api_gateway_rest_api" "this" {
  name                         = var.name
  description                  = "${var.name} REST API"
  api_key_source               = "HEADER"
  disable_execute_api_endpoint = var.enable_custom_domain

  endpoint_configuration {
    ip_address_type = "dualstack"
    types           = ["REGIONAL"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}"
    }
  )
}

resource "aws_api_gateway_rest_api_policy" "this" {
  count = local.rp_enabled ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.this.id
  policy      = data.aws_iam_policy_document.apigw_resource_policy[0].json
}

# パスから親パス・path_part を計算するローカル
locals {
  # メソッドで使われるすべてのパス
  method_paths = distinct(
    flatten([
      for m in concat(var.lambda_proxy_methods, var.sqs_methods) :
      [m.path]
    ])
  )

  # 各パスをセグメントに分解（"/" は特別扱い）
  # "/v1/hello"     -> ["v1", "hello"]
  # "/v1/{proxy+}"  -> ["v1", "{proxy+}"]
  # "/"             -> []
  method_segments = {
    for p in local.method_paths :
    p => (
      trim(p, "/") == "" ?
      [] :
      split("/", trim(p, "/"))
    )
  }

  ####################################
  # レベルごとのリソースパス（最大4階層）
  ####################################

  # level1: "/v1" "/v2" など
  level1_paths = distinct([
    for p, segs in local.method_segments :
    "/${segs[0]}"
    if length(segs) >= 1
  ])

  # level2: "/v1/hello" "/v1/{proxy+}" "/v1/enqueue" "/v2/enqueue" など
  level2_paths = distinct([
    for p, segs in local.method_segments :
    "/${segs[0]}/${segs[1]}"
    if length(segs) >= 2
  ])

  # level3: "/v1/foo/bar" など（必要になった時用）
  level3_paths = distinct([
    for p, segs in local.method_segments :
    "/${segs[0]}/${segs[1]}/${segs[2]}"
    if length(segs) >= 3
  ])

  # level4: "/v1/foo/bar/baz" など（必要になった時用）
  level4_paths = distinct([
    for p, segs in local.method_segments :
    "/${segs[0]}/${segs[1]}/${segs[2]}/${segs[3]}"
    if length(segs) >= 4
  ])
}

resource "aws_api_gateway_resource" "level1" {
  for_each = toset(local.level1_paths)

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = trimprefix(each.key, "/")
}

resource "aws_api_gateway_resource" "level2" {
  for_each = toset(local.level2_paths)

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id = aws_api_gateway_resource.level1[
    "/${split("/", trimprefix(each.key, "/"))[0]}"
  ].id
  path_part = split("/", trimprefix(each.key, "/"))[1]
}

resource "aws_api_gateway_resource" "level3" {
  for_each = toset(local.level3_paths)

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id = aws_api_gateway_resource.level2[
    "/${join("/", slice(split("/", trimprefix(each.key, "/")), 0, 2))}"
  ].id
  path_part = split("/", trimprefix(each.key, "/"))[2]
}

resource "aws_api_gateway_resource" "level4" {
  for_each = toset(local.level4_paths)

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id = aws_api_gateway_resource.level3[
    "/${join("/", slice(split("/", trimprefix(each.key, "/")), 0, 3))}"
  ].id
  path_part = split("/", trimprefix(each.key, "/"))[3]
}

locals {
  # メソッドの path -> 対応する resource_id
  method_resource_ids = {
    for p, segs in local.method_segments :
    p => (
      length(segs) == 0 ? aws_api_gateway_rest_api.this.root_resource_id :
      length(segs) == 1 ? aws_api_gateway_resource.level1["/${segs[0]}"].id :
      length(segs) == 2 ? aws_api_gateway_resource.level2["/${segs[0]}/${segs[1]}"].id :
      length(segs) == 3 ? aws_api_gateway_resource.level3["/${segs[0]}/${segs[1]}/${segs[2]}"].id :
      aws_api_gateway_resource.level4["/${segs[0]}/${segs[1]}/${segs[2]}/${segs[3]}"].id
    )
  }

  lambda_proxy_methods_map = {
    for m in var.lambda_proxy_methods :
    "${m.path} ${upper(m.http_method)}" => m
  }

  sqs_methods_map = {
    for m in var.sqs_methods :
    "${m.path} ${upper(m.http_method)}" => m
  }
}

############################
# Lambda プロキシ統合メソッド
############################
module "lambda_proxy_methods" {
  source = "./methods/lambda_proxy"

  for_each = local.lambda_proxy_methods_map

  rest_api_id      = aws_api_gateway_rest_api.this.id
  resource_id      = local.method_resource_ids[each.value.path]
  http_method      = upper(each.value.http_method)
  lambda_arn       = each.value.lambda_arn
  api_key_required = each.value.api_key_required
}

############################
# SQS 統合メソッド
############################
module "sqs_methods" {
  source = "./methods/sqs"

  for_each = local.sqs_methods_map

  rest_api_id                = aws_api_gateway_rest_api.this.id
  resource_id                = local.method_resource_ids[each.value.path]
  http_method                = upper(each.value.http_method)
  queue_arn                  = each.value.queue_arn
  queue_name                 = each.value.queue_name
  api_key_required           = each.value.api_key_required
  request_parameters         = each.value.request_parameters
  request_models             = each.value.request_models
  integration_http_method    = each.value.integration_http_method
  request_parameters_mapping = each.value.request_parameters_mapping
  request_templates_mapping  = each.value.request_templates_mapping
  responses                  = each.value.responses
  response_models            = each.value.response_models
}
