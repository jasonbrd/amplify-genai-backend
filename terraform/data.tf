data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# ---------------------------------------------------------------------------
# Shared REST API Gateway. Owned by the amplify-lambda module (Terraform now
# creates/imports it). Other services consume it via module outputs below.
# (Previously read from the ${stage}-RestApiId CloudFormation export, which was
# produced by the Serverless amplify-lambda stack.)
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Shared configuration parameters (written by the external IaC / bootstrap).
# These mirror the `${ssm:/amplify/<stage>/<KEY>}` references in serverless.yml.
# Add more here as services need them.
# ---------------------------------------------------------------------------
data "aws_ssm_parameter" "custom_api_domain" {
  name = "${local.ssm_shared_path}/CUSTOM_API_DOMAIN"
}

data "aws_ssm_parameter" "idp_prefix" {
  name = "${local.ssm_shared_path}/IDP_PREFIX"
}

data "aws_ssm_parameter" "oauth_audience" {
  name = "${local.ssm_shared_path}/OAUTH_AUDIENCE"
}

data "aws_ssm_parameter" "oauth_issuer_base_url" {
  name = "${local.ssm_shared_path}/OAUTH_ISSUER_BASE_URL"
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  partition  = data.aws_partition.current.partition

  rest_api_id               = module.amplify_lambda.rest_api_id
  rest_api_root_resource_id = module.amplify_lambda.root_resource_id

  # Common environment variables shared by every service (resolved from SSM,
  # matching the Serverless provider.environment block).
  shared_env = {
    LOG_LEVEL             = var.log_level
    STAGE                 = local.stage
    API_BASE_URL          = "https://${data.aws_ssm_parameter.custom_api_domain.value}"
    IDP_PREFIX            = data.aws_ssm_parameter.idp_prefix.value
    OAUTH_AUDIENCE        = data.aws_ssm_parameter.oauth_audience.value
    OAUTH_ISSUER_BASE_URL = data.aws_ssm_parameter.oauth_issuer_base_url.value
  }
}
