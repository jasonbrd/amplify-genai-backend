output "function_names" {
  value = { for k, m in module.fn : k => m.function_name }
}

output "role_arn" {
  value = aws_iam_role.lambda.arn
}

output "published_ssm_parameters" {
  value = module.ssm_publish.parameter_names
}

output "redeploy_trigger" {
  description = "Feed into the root API deployment so the shared stage redeploys on route changes."
  value       = module.routes.redeploy_trigger
}

output "table_names" {
  value = {
    acceptance = aws_dynamodb_table.acceptance.name
    versions   = aws_dynamodb_table.versions.name
  }
}

# Cross-service resource names consumed directly by sibling modules (replaces
# the SSM data-source reads other services used to perform).
output "published_params" {
  value = local.published_params
}
