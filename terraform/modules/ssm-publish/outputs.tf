output "parameter_names" {
  value = { for k, v in aws_ssm_parameter.this : k => v.name }
}

output "parameter_arns" {
  value = { for k, v in aws_ssm_parameter.this : k => v.arn }
}
