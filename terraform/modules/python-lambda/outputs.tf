output "function_name" {
  value = aws_lambda_function.this.function_name
}

output "function_arn" {
  value = aws_lambda_function.this.arn
}

output "invoke_arn" {
  description = "ARN used by API Gateway integrations."
  value       = aws_lambda_function.this.invoke_arn
}

output "role_arn" {
  value = local.role_arn
}

output "role_name" {
  description = "Name of the role if this module created it, else null."
  value       = local.create_role ? aws_iam_role.this[0].name : null
}
