locals {
  create_role = var.role_arn == null
  role_arn    = local.create_role ? aws_iam_role.this[0].arn : var.role_arn
}

data "aws_iam_policy_document" "assume" {
  count = local.create_role ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  count              = local.create_role ? 1 : 0
  name               = "${var.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume[0].json
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each   = local.create_role ? toset(var.managed_policy_arns) : toset([])
  role       = aws_iam_role.this[0].name
  policy_arn = each.value
}

# Explicit log group so retention is managed (Serverless set logRetentionInDays).
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "this" {
  function_name    = var.function_name
  handler          = var.handler
  runtime          = var.runtime
  architectures    = [var.architecture]
  role             = local.role_arn
  filename         = var.package_path
  source_code_hash = var.source_code_hash
  timeout          = var.timeout
  memory_size      = var.memory_size
  layers           = var.layer_arns

  reserved_concurrent_executions = var.reserved_concurrent_executions

  dynamic "environment" {
    for_each = length(var.environment) > 0 ? [1] : []
    content {
      variables = var.environment
    }
  }

  dynamic "tracing_config" {
    for_each = var.tracing_mode == null ? [] : [1]
    content {
      mode = var.tracing_mode
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config == null ? [] : [1]
    content {
      subnet_ids         = var.vpc_config.subnet_ids
      security_group_ids = var.vpc_config.security_group_ids
    }
  }

  depends_on = [aws_cloudwatch_log_group.this]
}
