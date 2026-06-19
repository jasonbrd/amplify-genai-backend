output "stage" {
  description = "Active stage (Terraform workspace)."
  value       = local.stage
}

output "rest_api_id" {
  description = "Shared REST API Gateway ID (owned by the amplify-lambda module)."
  value       = local.rest_api_id
}

output "amplify_lambda_function_names" {
  value = module.amplify_lambda.function_names
}

output "data_disclosure_function_names" {
  description = "Lambda function names created by the data-disclosure service."
  value       = module.data_disclosure.function_names
}

output "object_access_function_names" {
  description = "Lambda function names created by the object-access service."
  value       = module.object_access.function_names
}

output "chat_billing_function_names" {
  value = module.chat_billing.function_names
}

output "artifacts_function_names" {
  value = module.amplify_lambda_artifacts.function_names
}

output "ops_function_names" {
  value = module.amplify_lambda_ops.function_names
}

output "api_function_names" {
  value = module.amplify_lambda_api.function_names
}

output "admin_function_names" {
  value = module.amplify_lambda_admin.function_names
}

output "admin_table_stream_arn" {
  description = "Admin configs table stream ARN (replaces the CFN export consumed by assistants-api google/office365)."
  value       = module.amplify_lambda_admin.admin_table_stream_arn
}

output "assistants_api_function_names" {
  value = module.assistants_api.function_names
}

output "assistants_api_google_function_names" {
  value = module.assistants_api_google.function_names
}

output "assistants_api_office365_function_names" {
  value = module.assistants_api_office365.function_names
}

output "amplify_assistants_function_names" {
  value = module.amplify_assistants.function_names
}

output "embedding_function_names" {
  value = module.embedding.function_names
}

output "amplify_lambda_js_function_names" {
  value = module.amplify_lambda_js.function_names
}

output "amplify_agent_loop_function_names" {
  value = module.amplify_agent_loop.function_names
}
