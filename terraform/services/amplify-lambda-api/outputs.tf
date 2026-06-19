output "function_names" {
  value = { for k, m in module.fn : k => m.function_name }
}

output "role_arn" {
  value = aws_iam_role.lambda.arn
}

output "security_group_id" {
  value = aws_security_group.notebook_proxy.id
}

output "redeploy_trigger" {
  value = module.routes.redeploy_trigger
}
