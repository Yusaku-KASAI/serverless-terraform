variable "profile" {
  description = "AWS CLI プロファイル名"
  type        = string
  default     = ""
}

variable "slack_team_id" {
  description = "通知先 Slack Workspace ID"
  type        = string
}
variable "slack_channel_id" {
  description = "通知先 Slack Channel ID"
  type        = string
}

variable "lambda_subnet_ids" {
  description = "Lambda を配置するサブネット ID 一覧"
  type        = list(string)
  default     = []
}
variable "lambda_security_group_ids" {
  description = "Lambda に紐付けるセキュリティグループ ID 一覧"
  type        = list(string)
  default     = []
}

variable "dlq_arn" {
  type        = string
  description = "Event Invoke Config の Dead Letter Queue 用 SQS キュー ARN"
}
variable "failure_queue_arn" {
  type        = string
  description = "Event Invoke Config の On Failure 用 SQS キュー ARN"
}
variable "success_queue_arn" {
  type        = string
  description = "Event Invoke Config の On Success 用 SQS キュー ARN"
}

variable "queue_main_arn" {
  description = "メイン SQS キューの ARN"
  type        = string
}
variable "queue_second_arn" {
  description = "セカンド SQS キューの ARN"
  type        = string
}
variable "sns_topic_main_arn" {
  description = "メイン SNS トピックの ARN"
  type        = string
}
