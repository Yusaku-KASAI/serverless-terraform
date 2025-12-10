resource "aws_lambda_function" "this" {
  function_name = var.function_name
  description   = var.description
  role          = aws_iam_role.this.arn

  package_type = "Image"
  image_uri    = "${aws_ecr_repository.this.repository_url}:${var.image_tag}"
  publish      = true

  memory_size                    = var.memory_size
  timeout                        = var.timeout
  architectures                  = ["x86_64"]
  reserved_concurrent_executions = var.reserved_concurrent_executions

  environment {
    variables = var.environment_variables
  }

  ephemeral_storage {
    size = var.storage_size
  }

  logging_config {
    log_format            = "JSON"
    application_log_level = "INFO"
    system_log_level      = "INFO"
    log_group             = aws_cloudwatch_log_group.this.name
  }

  tracing_config {
    mode = var.use_xray ? "Active" : "PassThrough"
  }

  dynamic "vpc_config" {
    for_each = var.use_vpc ? [1] : []

    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids
    }
  }

  dynamic "dead_letter_config" {
    for_each = var.dlq_arn != "" ? [1] : []

    content {
      target_arn = var.dlq_arn
    }
  }

  tags = merge(var.tags, {
    Name = "${var.function_name}"
    }
  )
}

resource "aws_lambda_function_recursion_config" "this" {
  function_name  = aws_lambda_function.this.function_name
  recursive_loop = "Terminate"
}

resource "aws_lambda_function_event_invoke_config" "this" {
  function_name                = aws_lambda_function.this.function_name
  maximum_event_age_in_seconds = 60 # 1 minute - fail fast
  maximum_retry_attempts       = 0  # No retries

  dynamic "destination_config" {
    for_each = (var.destination_on_failure_arn != "" || var.destination_on_success_arn != "") ? [1] : []

    content {
      dynamic "on_failure" {
        for_each = var.destination_on_failure_arn != "" ? [1] : []

        content {
          destination = var.destination_on_failure_arn
        }
      }
      dynamic "on_success" {
        for_each = var.destination_on_success_arn != "" ? [1] : []

        content {
          destination = var.destination_on_success_arn
        }
      }
    }
  }
}
