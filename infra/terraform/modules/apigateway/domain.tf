# カスタムドメイン（任意）
resource "aws_api_gateway_domain_name" "this" {
  count = var.enable_custom_domain ? 1 : 0

  domain_name              = var.domain_name
  security_policy          = "TLS_1_2"
  regional_certificate_arn = var.acm_certificate_arn

  endpoint_configuration {
    ip_address_type = "dualstack"
    types           = ["REGIONAL"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-custom-domain"
    }
  )
}

resource "aws_api_gateway_base_path_mapping" "this" {
  count = var.enable_custom_domain ? 1 : 0

  domain_name = aws_api_gateway_domain_name.this[0].domain_name
  api_id      = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
}

# A レコード相当
resource "aws_route53_record" "apigw" {
  count = var.enable_custom_domain ? 1 : 0

  zone_id = var.zone_id
  name    = aws_api_gateway_domain_name.this[0].domain_name
  type    = "A"

  alias {
    name                   = aws_api_gateway_domain_name.this[0].regional_domain_name
    zone_id                = aws_api_gateway_domain_name.this[0].regional_zone_id
    evaluate_target_health = false
  }
}

# AAAA レコード相当
resource "aws_route53_record" "apigw_ipv6" {
  count = var.enable_custom_domain ? 1 : 0

  zone_id = var.zone_id
  name    = aws_api_gateway_domain_name.this[0].domain_name
  type    = "AAAA"

  alias {
    name                   = aws_api_gateway_domain_name.this[0].regional_domain_name
    zone_id                = aws_api_gateway_domain_name.this[0].regional_zone_id
    evaluate_target_health = false
  }
}
