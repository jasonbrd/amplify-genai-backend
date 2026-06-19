# -----------------------------------------------------------------------------
# Custom API domain — replaces serverless-domain-manager on amplify-lambda.
#
# The Serverless customDomain block was:
#   domainName: ${ssm:/amplify/<stage>/CUSTOM_API_DOMAIN}
#   certificateName: (blank)  basePath: (blank)  stage: <stage>
#   createRoute53Record: true  autoDomain: true
# i.e. an EDGE custom domain, ACM cert auto-discovered by domain name, root
# base-path mapping, and an alias record in the (externally owned) hosted zone.
#
# IMPORTANT: serverless-domain-manager creates these via the AWS SDK during
# deploy hooks, NOT via CloudFormation — so they are NOT in the CFN stack and do
# NOT appear in gen-imports.sh. Import them manually per stage (after selecting
# the workspace):
#   terraform import 'module.amplify_lambda.aws_api_gateway_domain_name.api[0]' '<domain>'
#   terraform import 'module.amplify_lambda.aws_api_gateway_base_path_mapping.api[0]' '<domain>/'
#   terraform import 'module.amplify_lambda.aws_route53_record.api_a[0]' '<zone_id>_<domain>_A'
#   terraform import 'module.amplify_lambda.aws_route53_record.api_aaaa[0]' '<zone_id>_<domain>_AAAA'
#
# Set custom_domain_enabled=false for environments where the domain is owned
# elsewhere (e.g. the external IaC).
# -----------------------------------------------------------------------------

locals {
  custom_domain = var.custom_api_domain

  # Parent hosted-zone name = domain minus its first label
  # (api.example.com -> example.com). Override via var.route53_zone_id when the
  # zone is not the immediate parent.
  derived_zone_name = join(".", slice(
    split(".", local.custom_domain), 1, length(split(".", local.custom_domain))
  ))

  api_cert_arn = var.custom_domain_enabled ? (
    var.api_custom_domain_certificate_arn != "" ? var.api_custom_domain_certificate_arn : data.aws_acm_certificate.api[0].arn
  ) : null

  api_zone_id = var.custom_domain_enabled ? (
    var.route53_zone_id != "" ? var.route53_zone_id : data.aws_route53_zone.api[0].zone_id
  ) : null
}

# EDGE custom domains require the ACM certificate in us-east-1. When dep_region
# is us-east-1 (the default) this default-provider lookup is correct; for other
# regions, pass api_custom_domain_certificate_arn explicitly (a us-east-1 ARN).
data "aws_acm_certificate" "api" {
  count       = var.custom_domain_enabled && var.api_custom_domain_certificate_arn == "" ? 1 : 0
  domain      = local.custom_domain
  statuses    = ["ISSUED"]
  most_recent = true
}

# Hosted zone is externally owned (gaiin-platform). Looked up by the derived
# parent name unless route53_zone_id is supplied.
data "aws_route53_zone" "api" {
  count        = var.custom_domain_enabled && var.route53_zone_id == "" ? 1 : 0
  name         = "${local.derived_zone_name}."
  private_zone = false
}

resource "aws_api_gateway_domain_name" "api" {
  count           = var.custom_domain_enabled ? 1 : 0
  domain_name     = local.custom_domain
  certificate_arn = local.api_cert_arn
  security_policy = "TLS_1_2"

  endpoint_configuration {
    types = ["EDGE"]
  }
}

resource "aws_api_gateway_base_path_mapping" "api" {
  count       = var.custom_domain_enabled ? 1 : 0
  api_id      = aws_api_gateway_rest_api.shared.id
  domain_name = aws_api_gateway_domain_name.api[0].domain_name
  stage_name  = var.stage
  # base_path omitted => root "(none)" mapping, matching the blank basePath.

  # The shared stage is created by the route module's create-deployment call;
  # ensure it exists before mapping the domain to it.
  depends_on = [module.routes]
}

resource "aws_route53_record" "api_a" {
  count   = var.custom_domain_enabled ? 1 : 0
  zone_id = local.api_zone_id
  name    = local.custom_domain
  type    = "A"

  alias {
    name                   = aws_api_gateway_domain_name.api[0].cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.api[0].cloudfront_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "api_aaaa" {
  count   = var.custom_domain_enabled ? 1 : 0
  zone_id = local.api_zone_id
  name    = local.custom_domain
  type    = "AAAA"

  alias {
    name                   = aws_api_gateway_domain_name.api[0].cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.api[0].cloudfront_zone_id
    evaluate_target_health = false
  }
}
