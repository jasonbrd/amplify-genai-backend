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
    assistants              = aws_dynamodb_table.assistants.name
    assistants_aliases      = aws_dynamodb_table.assistants_aliases.name
    ast_lookup              = aws_dynamodb_table.ast_lookup.name
    layered_assistants      = aws_dynamodb_table.layered_assistants.name
    ast_threads             = aws_dynamodb_table.ast_threads.name
    ast_thread_runs         = aws_dynamodb_table.ast_thread_runs.name
    ast_code_interpreter    = aws_dynamodb_table.ast_code_interpreter.name
    group_ast_conversations = aws_dynamodb_table.group_ast_conversations.name
  }
}

# Cross-service resource names consumed directly by sibling modules (replaces
# the SSM data-source reads other services used to perform).
output "published_params" {
  value = local.published_params
}
