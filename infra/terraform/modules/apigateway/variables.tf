# メタ情報
variable "project" {
  type        = string
  description = "プロジェクト識別子"
  default     = ""
}

variable "tags" {
  type        = map(any)
  description = "リソースに付与するタグ"
  default     = {}
}

# apigateway 基本設定
variable "name" {
  type        = string
  description = "apigateway 名（pj名含む想定）"
}

variable "stage_name" {
  type        = string
  description = "ステージ名(同一環境で複数ステージは想定しないがデプロイ時に使用する)"
  default     = "prod"
}

# ip制限
variable "allowed_source_ips" {
  type        = list(string)
  description = "許可する Source IP CIDR（指定すると allowlist 運用: それ以外は拒否）"
  default     = []
}

variable "denied_source_ips" {
  type        = list(string)
  description = "拒否する Source IP CIDR（deny は allow より優先）"
  default     = []
}

# APIキーまわり
variable "enable_api_key" {
  type        = bool
  description = "APIキーを作成するかどうか"
  default     = false
}

variable "usage_plan_throttle" {
  type = object({
    rate_limit  = optional(number, null)
    burst_limit = optional(number, null)
  })
  description = "使用量プランのスロットル指定"
  default = {
    rate_limit  = null
    burst_limit = null
  }
}

variable "usage_plan_quota" {
  type = object({
    limit  = optional(number, null)
    period = optional(string, null)
  })
  description = "使用量プランのクオータ指定"
  default = {
    limit  = null
    period = null
  }
}

# カスタムドメイン（基本カスタムにしたい、cookie周りとかがちょい不安なので）
variable "enable_custom_domain" {
  type        = bool
  description = "カスタムドメインを有効にするかどうか"
  default     = true
}

variable "domain_name" {
  type        = string
  description = "api.example.com のようなカスタムドメイン名"
  default     = ""
}

variable "acm_certificate_arn" {
  type        = string
  description = "カスタムドメインで仕様するACMのarn"
  default     = ""
}

variable "zone_id" {
  type        = string
  description = "カスタムドメイン周りでレコードを作成する既存のRoute53 hosted zone id"
  default     = ""
}

# Lambda プロキシ統合用メソッド定義
variable "lambda_proxy_methods" {
  type = list(object({
    path             = string # "/v1/hello" など
    http_method      = string # "GET", "POST" など
    lambda_arn       = string
    api_key_required = optional(bool, false)
  }))
  description = "AWSのLambdaプロキシ統合で動作するメソッドたちの定義"
  default     = []
}

# SQS 統合用メソッド定義
variable "sqs_methods" {
  type = list(object({
    path             = string # "/v1/enqueue" など
    http_method      = string # "POST" など
    queue_arn        = string
    queue_name       = string
    api_key_required = optional(bool, false)

    # aws_api_gateway_method 用
    request_parameters = optional(map(string), {})
    request_models     = optional(map(string), {})

    # aws_api_gateway_integration 用
    integration_http_method    = optional(string, "POST")
    request_parameters_mapping = optional(map(string), {})
    request_templates_mapping  = optional(map(string), {})

    # responses → サブモジュールの variables.responses にそのまま渡す（プロキシ統合じゃないので指定必須のはず）
    responses = list(object({
      status_code                 = string                    # ユニークである必要あり（たぶん）
      selection_pattern           = optional(string, "")      # "" なら指定なしでデフォルト、正規表現で排他的に指定する
      response_models             = optional(map(string), {}) # content-type => モデル名
      response_parameters_mapping = optional(map(string), {}) # レスポンスパラメータマッピング
      response_templates_mapping  = optional(map(string), {}) # content-type => テンプレート文字列
    }))

    # aws_api_gateway_model.response_models 用（キーがモデル名）
    response_models = optional(map(object({
      content_type = string
      schema       = string
    })), {})
  }))
  description = "AWSのSQSと非プロキシ統合で動作するメソッドたちの定義"
  default     = []
}


# 監視・トレーシングまわり
variable "access_log_retention_in_days" {
  type        = number
  description = "アクセスログの保持日数"
  default     = 731
}

variable "execution_log_retention_in_days" {
  type        = number
  description = "実行ログの保持日数"
  default     = 731
}

variable "stage_alarm_config" {
  type = object({
    five_xx_error_threshold = optional(number, null)
    four_xx_error_threshold = optional(number, null)
    latency_threshold_ms    = optional(number, null)
    count_threshold         = optional(number, null)
  })
  description = "ステージ全体のアラーム閾値設定"
  default     = {}
}

variable "use_xray" {
  type        = bool
  description = "X-Ray トレーシングを有効にするかどうか"
  default     = false
}

variable "manage_apigw_account_logging_role" {
  type        = bool
  description = "API Gateway の CloudWatch Logs 連携用の アカウントレベルの IAM ロールをこのモジュールで管理するかどうか"
  default     = true
}
