variable "rest_api_id" {
  type = string
}

variable "resource_id" {
  type = string
}

variable "http_method" {
  type    = string
  default = "POST"
}

variable "queue_arn" {
  type = string
}

variable "queue_name" {
  type = string
}

variable "api_key_required" {
  type    = bool
  default = false
}

variable "request_parameters" {
  type    = map(string)
  default = {}
}

variable "request_models" {
  type    = map(string)
  default = {}
}

variable "integration_http_method" {
  type    = string
  default = "POST"
}

# リクエストパラメータマッピング（デフォルト：SQS SendMessage 用）
variable "request_parameters_mapping" {
  type    = map(string)
  default = {}
}

# リクエストテンプレート（デフォルト：SQS SendMessage 用）
variable "request_templates_mapping" {
  type    = map(string)
  default = {}
}

# response 定義を引数で可変にする
# status_code ごとに method_response / integration_response を自動生成するイメージ
# 整合性をとるため、status_code と selection_pattern は本来1対多だがこのモジュールでは1対1対応している必要がある
variable "responses" {
  type = list(object({
    status_code                 = string
    response_models             = map(string)
    selection_pattern           = string # "" ならなし（デフォルト）、正規表現で排他的に指定
    response_parameters_mapping = map(string)
    response_templates_mapping  = map(string)
  }))
  default = []
}

variable "response_models" {
  type = map(object({
    content_type = string
    schema       = string
  }))
  default = {}
}
