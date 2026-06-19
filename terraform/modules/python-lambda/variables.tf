variable "function_name" {
  description = "Full Lambda function name."
  type        = string
}

variable "handler" {
  description = "Lambda handler (module.function), e.g. data_disclosure.check_data_disclosure_decision."
  type        = string
}

variable "package_path" {
  description = "Path to the prebuilt deployment zip for this service."
  type        = string
}

variable "source_code_hash" {
  description = "base64sha256 of the deployment package, for change detection."
  type        = string
}

variable "runtime" {
  type    = string
  default = "python3.11"
}

variable "architecture" {
  type    = string
  default = "x86_64"
}

variable "timeout" {
  type    = number
  default = 6
}

variable "memory_size" {
  type    = number
  default = 128
}

variable "layer_arns" {
  description = "Lambda layer ARNs to attach (deps layer, markitdown, pandoc, etc.)."
  type        = list(string)
  default     = []
}

variable "environment" {
  description = "Environment variables for the function."
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "CloudWatch log retention (Serverless used 365 for 800-171 compliance)."
  type        = number
  default     = 365
}

variable "tracing_mode" {
  description = "X-Ray tracing mode: PassThrough or Active. null disables tracing config."
  type        = string
  default     = null
}

variable "vpc_config" {
  description = "Optional VPC config. null = no VPC."
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "reserved_concurrent_executions" {
  description = "Reserved concurrency. -1 (default) leaves it unreserved."
  type        = number
  default     = -1
}

# --- Role wiring ---------------------------------------------------------
# Provide role_arn to reuse a shared per-service role (the dominant pattern).
# Leave role_arn null to have this module create a dedicated role (covers the
# serverless-iam-roles-per-function case) from managed_policy_arns.
variable "role_arn" {
  description = "Existing IAM role ARN to use. If null, a dedicated role is created."
  type        = string
  default     = null
}

variable "managed_policy_arns" {
  description = "Managed policy ARNs attached when this module creates the role."
  type        = list(string)
  default     = []
}
