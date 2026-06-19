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
  value = module.routes.redeploy_trigger
}

output "oauth_user_table" {
  description = "Consumed by the google/office365 integration services."
  value       = aws_dynamodb_table.oauth_user.name
}

output "table_names" {
  value = {
    oauth_state = aws_dynamodb_table.oauth_state.name
    oauth_user  = aws_dynamodb_table.oauth_user.name
    op_log      = aws_dynamodb_table.op_log.name
    job_status  = aws_dynamodb_table.job_status.name
  }
}

# Cross-service resource names consumed directly by sibling modules (replaces
# the SSM data-source reads other services used to perform).
output "published_params" {
  value = local.published_params
}
