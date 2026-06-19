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

output "agent_queue_arn" {
  value = aws_sqs_queue.agent.arn
}

# Cross-service resource names consumed directly by sibling modules (replaces
# the SSM data-source reads other services used to perform).
output "published_params" {
  value = local.published_params
}
