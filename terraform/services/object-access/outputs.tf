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

output "table_names" {
  value = {
    object_access      = aws_dynamodb_table.object_access.name
    cognito_users      = aws_dynamodb_table.cognito_users.name
    api_keys           = aws_dynamodb_table.api_keys.name
    amplify_groups     = aws_dynamodb_table.amplify_groups.name
    amplify_group_logs = aws_dynamodb_table.amplify_group_logs.name
  }
}

# Cross-service resource names consumed directly by sibling modules (replaces
# the SSM data-source reads other services used to perform).
output "published_params" {
  value = local.published_params
}
