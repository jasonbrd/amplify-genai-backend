output "function_names" {
  value = { for k, m in module.fn : k => m.function_name }
}

output "chat_function_url" {
  description = "RESPONSE_STREAM Function URL for the chat handler."
  value       = module.fn["chat"].function_url
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

# Cross-service resource names consumed directly by sibling modules (replaces
# the SSM data-source reads other services used to perform).
output "published_params" {
  value = local.published_params
}
