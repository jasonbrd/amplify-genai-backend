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

# These replace the former CloudFormation exports. Other Terraform modules
# (assistants-api-google/office365) consume admin_table_stream_arn directly.
output "admin_table_stream_arn" {
  description = "Replaces export ${"$"}{stage}-AmplifyAdminTableStreamArn"
  value       = aws_dynamodb_table.admin_configs.stream_arn
}

output "critical_errors_queue_arn" {
  value = aws_sqs_queue.critical_errors.arn
}

output "critical_errors_queue_url" {
  value = aws_sqs_queue.critical_errors.url
}

output "critical_errors_topic_arn" {
  value = aws_sns_topic.critical_errors.arn
}

output "table_names" {
  value = {
    admin_configs   = aws_dynamodb_table.admin_configs.name
    admin_logs      = aws_dynamodb_table.admin_logs.name
    critical_errors = aws_dynamodb_table.critical_errors.name
  }
}

# Cross-service resource names consumed directly by sibling modules (replaces
# the SSM data-source reads other services used to perform). String names only;
# the stream ARN is exposed via the dedicated admin_table_stream_arn output.
output "published_params" {
  value = local.published_params
}
