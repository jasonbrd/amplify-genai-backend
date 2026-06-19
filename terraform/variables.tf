# Inputs that cannot be derived from the workspace or from SSM at plan time.
# These mirror the not-in-SSM values from var/<stage>-var.yml. Most runtime
# configuration (Cognito, OAuth, domain, secret ARNs, cross-service table names)
# is read at deploy time from SSM Parameter Store via data sources, exactly as
# the Serverless `${ssm:...}` references did.

variable "dep_name" {
  description = "Deployment name (DEP_NAME). Must be < 10 chars, no spaces. Used in resource naming: amplify-<dep_name>-<service>."
  type        = string

  validation {
    condition     = length(var.dep_name) > 0 && length(var.dep_name) < 10 && !can(regex("\\s", var.dep_name))
    error_message = "dep_name must be 1-9 characters and contain no spaces."
  }
}

variable "dep_region" {
  description = "AWS region for the deployment (DEP_REGION)."
  type        = string
  default     = "us-east-1"
}

variable "log_level" {
  description = "Lambda LOG_LEVEL (DEBUG|INFO|WARNING|ERROR|CRITICAL)."
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"], var.log_level)
    error_message = "log_level must be one of DEBUG, INFO, WARNING, ERROR, CRITICAL."
  }
}

variable "default_tags" {
  description = "Tags applied to all resources via the provider default_tags block."
  type        = map(string)
  default     = {}
}

# ---- Custom API domain (amplify-lambda owns it; replaces serverless-domain-manager) ----
variable "custom_domain_enabled" {
  description = "Manage the API custom domain + base-path mapping + Route53 alias in Terraform (amplify-lambda module). Set false where the domain is owned by external IaC."
  type        = bool
  default     = true
}

variable "api_custom_domain_certificate_arn" {
  description = "ACM certificate ARN for the custom domain. Must be in us-east-1 for an EDGE domain. Empty = auto-discover by domain name. Required when dep_region is not us-east-1."
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for the custom domain record. Empty = look up by the domain's parent zone name."
  type        = string
  default     = ""
}
