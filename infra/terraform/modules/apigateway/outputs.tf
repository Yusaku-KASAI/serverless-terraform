output "rest_api_id" {
  value = aws_api_gateway_rest_api.this.id
}

output "root_resource_id" {
  value = aws_api_gateway_rest_api.this.root_resource_id
}

output "execution_arn" {
  value = aws_api_gateway_rest_api.this.execution_arn
}

output "stage_name" {
  value = aws_api_gateway_stage.this.stage_name
}

output "api_key_value" {
  value       = var.enable_api_key ? aws_api_gateway_api_key.this[0].value : null
  description = "Actual API key value"
  sensitive   = true
}

# 階層ごとのリソースID（必要に応じて使い分けたい場合）
output "level1_resource_ids" {
  description = "Map of level1 resource paths to resource IDs (e.g. /v1)"
  value = {
    for p, r in aws_api_gateway_resource.level1 :
    p => r.id
  }
}

output "level2_resource_ids" {
  description = "Map of level2 resource paths to resource IDs (e.g. /v1/hello)"
  value = {
    for p, r in aws_api_gateway_resource.level2 :
    p => r.id
  }
}

output "level3_resource_ids" {
  description = "Map of level3 resource paths to resource IDs (e.g. /v1/foo/bar)"
  value = {
    for p, r in aws_api_gateway_resource.level3 :
    p => r.id
  }
}

output "level4_resource_ids" {
  description = "Map of level4 resource paths to resource IDs (e.g. /v1/foo/bar/baz)"
  value = {
    for p, r in aws_api_gateway_resource.level4 :
    p => r.id
  }
}

# 全てのリソースID
output "resource_ids" {
  description = "Map of full resource paths to resource IDs (excluding root /)"
  value = merge(
    { "/" = aws_api_gateway_rest_api.this.root_resource_id },
    { for p, r in aws_api_gateway_resource.level1 : p => r.id },
    { for p, r in aws_api_gateway_resource.level2 : p => r.id },
    { for p, r in aws_api_gateway_resource.level3 : p => r.id },
    { for p, r in aws_api_gateway_resource.level4 : p => r.id }
  )
}
