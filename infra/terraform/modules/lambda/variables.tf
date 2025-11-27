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

# lambda 基本設定
variable "function_name" {
  type        = string
  description = "Lambda 関数名（ユニークにする）"
}

variable "description" {
  type        = string
  description = "Lambda 関数の説明"
  default     = ""
}

variable "extra_policy_arns" {
  type        = list(string)
  description = "Lambda 実行ロールに追加で付与するマネージドポリシー ARN リスト"
  default     = []
}

variable "ecr_repository_name" {
  type        = string
  description = "ECR リポジトリ名"
}

variable "image_tag" {
  type        = string
  description = "使用する ECR イメージタグ"
  default     = "latest"
}

# lambda 実行設定
variable "memory_size" {
  type        = number
  description = "Lambda のメモリ（MB）"
  default     = 512
}

variable "timeout" {
  type        = number
  description = "Lambda のタイムアウト（秒）"
  default     = 10
}

variable "storage_size" {
  type        = number
  description = "Lambda のエフェメラルストレージサイズ（MB）"
  default     = 512
}

variable "environment_variables" {
  type        = map(string)
  description = "Lambda の環境変数"
  default     = {}
}

# VPC 設定
variable "subnet_ids" {
  type        = list(string)
  description = "VPC Lambda 用 subnet IDs（use_vpc = true のとき必須）"
  default     = []
}

variable "security_group_ids" {
  type        = list(string)
  description = "VPC Lambda 用 security group IDs（use_vpc = true のとき必須）"
  default     = []
}

# DLQ / Destination 設定
variable "dlq_arn" {
  type        = string
  description = "Dead Letter Queue の SQS or SNS ARN"
  default     = ""
}

variable "destination_on_failure_arn" {
  type        = string
  description = "Event Invoke Config の On Failure 用 SQS or SNS ARN（lambda等他は非対応）"
  default     = ""
}

variable "destination_on_success_arn" {
  type        = string
  description = "Event Invoke Config の On Success 用 SQS or SNS ARN（lambda等他は非対応）"
  default     = ""
}

# イベントソース設定
variable "eventbridge_schedules" {
  type = list(object({
    name                = string # ルール名
    schedule_expression = string # rate(...) or cron(...)
  }))
  description = "EventBridge スケジュール定義のリスト"
  default     = []
}

variable "sns_event_sources" {
  type = list(object({
    name      = string # 識別用
    topic_arn = string
  }))
  description = "SNS をイベントソースとして使う設定一覧"
  default     = []
}

variable "sqs_event_sources" {
  type = list(object({
    name                           = string # 識別用
    queue_arn                      = string
    batch_size                     = optional(number, 10)
    maximum_batching_window_second = optional(number, 0)
  }))
  description = "SQS をイベントソースとして使う設定一覧（SQS の Visibility Timeout > lambda の Timeout に注意）"
  default     = []
}

# ログ・モニタリング設定
variable "log_retention_in_days" {
  type        = number
  description = "CloudWatch Logs の保持日数"
  default     = 731
}

variable "error_alarm_threshold" {
  type        = number
  description = "直近3分の1分あたりの合計 Errors 回数閾値"
  default     = 1
}

variable "throttle_alarm_threshold" {
  type        = number
  description = "直近3分の1分あたりの合計 Throttles 回数閾値"
  default     = 1
}

variable "duration_alarm_threshold" {
  type        = number
  description = "直近15分の最大 Duration ミリ秒数閾値"
  default     = 5000
}

variable "invocation_alarm_threshold" {
  type        = number
  description = "直近15分の5分あたりの合計 Invocations 回数閾値"
  default     = 1000
}

variable "memory_alarm_threshold" {
  type        = number
  description = "直近15分の最大メモリ使用率閾値(%)"
  default     = 80
}

# フラグ設定
variable "use_vpc" {
  type        = bool
  description = "Lambda を VPC 内で動かすかどうか（ NAT や VPCendpoint はこのモジュールで管理しないが、どちらかがないと lambda insights が動かない。vpc全体としてどちらを採用するか決める必要がある）"
  default     = false
}

variable "use_xray" {
  type        = bool
  description = "X-Ray トレーシングを有効にするかどうか"
  default     = false
}
