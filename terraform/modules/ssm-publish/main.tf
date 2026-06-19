# Replaces the Lambda-backed ParameterStoreAutoPopulate custom resource with
# native, declarative SSM parameters. Each service publishes its locally-defined
# resource names here so other services can consume them via data sources.

resource "aws_ssm_parameter" "this" {
  for_each = var.parameters

  name  = "${var.base_path}/${each.key}"
  type  = "String"
  value = each.value
  tier  = var.tier
}
