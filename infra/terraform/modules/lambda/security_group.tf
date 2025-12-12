resource "aws_security_group" "this" {
  count = var.use_vpc && length(var.security_group_ids) == 0 ? 1 : 0

  name        = "${var.function_name}-sg"
  description = "Security group for Lambda function ${var.function_name}"
  vpc_id      = local.inferred_vpc_id

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = "0"
    protocol    = "-1"
    self        = false
    to_port     = "0"
  }

  tags = {
    Name = "${var.function_name}-lambda-sg"
  }
}

data "aws_subnet" "first" {
  count = length(var.subnet_ids) > 0 ? 1 : 0
  id    = var.subnet_ids[0]
}

locals {
  inferred_vpc_id = length(var.subnet_ids) > 0 ? data.aws_subnet.first[0].vpc_id : ""
}
