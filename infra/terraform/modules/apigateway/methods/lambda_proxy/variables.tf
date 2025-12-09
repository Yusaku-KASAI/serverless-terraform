variable "rest_api_id" {
  type = string
}

variable "resource_id" {
  type = string
}

variable "http_method" {
  type    = string
  default = "GET"
}

variable "lambda_arn" {
  type = string
}

variable "api_key_required" {
  type    = bool
  default = false
}
