variable "project" {
  type    = string
  default = ""
}

variable "configuration_name" {
  description = "AmazonQ(chatbot)の設定名"
  type        = string
  default     = ""
}

variable "slack_team_id" {
  description = "AmazonQ(chatbot)のslack通知先ワークスペース"
  type        = string
  default     = ""
}

variable "slack_channel_id" {
  description = "AmazonQ(chatbot)のslack通知先チャンネル"
  type        = string
  default     = ""
}

variable "sns_topic_arns" {
  description = "Chatbot に通知する SNS トピック ARN リスト"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "リソースに付与するタグ"
  type        = map(any)
  default     = {}
}

locals {
  configuration_name = (
    var.configuration_name != "" ?
    var.configuration_name :
    "${var.project}-chatbot-slack"
  )
}
