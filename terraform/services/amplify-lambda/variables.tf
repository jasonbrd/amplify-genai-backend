variable "stage" { type = string }
variable "region" { type = string }
variable "account_id" { type = string }
variable "partition" { type = string }
variable "name_prefix" { type = string } # amplify-<dep_name>

variable "ssm_shared_path" { type = string }
variable "ssm_base_path" { type = string }

variable "shared_env" {
  type = map(string)
}

variable "api_gateway_max_timeout_ms" {
  description = "Integration timeout (ms) for long-running routes (e.g. chat). null = AWS default."
  type        = number
  default     = null
}

# ---- Custom API domain (replaces serverless-domain-manager) ----
variable "custom_api_domain" {
  description = "API custom domain name (from SSM CUSTOM_API_DOMAIN). Used for the EDGE custom domain + base-path mapping + Route53 alias."
  type        = string
  default     = ""
}

variable "custom_domain_enabled" {
  description = "Create/manage the custom domain, base-path mapping and Route53 alias here. Set false when the domain is owned elsewhere."
  type        = bool
  default     = true
}

variable "api_custom_domain_certificate_arn" {
  description = "ACM certificate ARN for the custom domain (must be us-east-1 for an EDGE domain). Empty = auto-discover by domain name via data source."
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for the custom domain record. Empty = look up by the domain's parent zone name."
  type        = string
  default     = ""
}

# Cross-service producer module outputs (passed in instead of read from SSM).
variable "chat_billing_params" { type = map(string) }
variable "admin_params" { type = map(string) }
variable "object_access_params" { type = map(string) }
variable "amplify_js_params" { type = map(string) }
variable "embedding_params" { type = map(string) }
variable "lambda_ops_params" { type = map(string) }
variable "data_disclosure_params" { type = map(string) }
