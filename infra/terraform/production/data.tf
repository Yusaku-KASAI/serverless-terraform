data "aws_sqs_queue" "sqs_main" {
  name = split(":", var.queue_main_arn)[5]
}

data "aws_sqs_queue" "sqs_second" {
  name = split(":", var.queue_second_arn)[5]
}
