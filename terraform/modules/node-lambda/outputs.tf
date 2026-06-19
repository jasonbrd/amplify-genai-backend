output "function_name" {
  value = aws_lambda_function.this.function_name
}

output "function_arn" {
  value = aws_lambda_function.this.arn
}

output "invoke_arn" {
  value = aws_lambda_function.this.invoke_arn
}

output "function_url" {
  description = "Function URL if configured, else null."
  value       = var.function_url == null ? null : aws_lambda_function_url.this[0].function_url
}

output "role_arn" {
  value = local.role_arn
}

output "role_name" {
  value = local.create_role ? aws_iam_role.this[0].name : null
}
