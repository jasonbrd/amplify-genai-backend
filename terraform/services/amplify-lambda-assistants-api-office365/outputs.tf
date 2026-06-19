output "function_names" {
  value = { for k, m in module.fn : k => m.function_name }
}

output "role_arn" {
  value = aws_iam_role.lambda.arn
}

output "redeploy_trigger" {
  value = module.routes.redeploy_trigger
}
