variable "function_name" {
  type = string
}

variable "handler" {
  type = string
}

variable "package_path" {
  type = string
}

variable "source_code_hash" {
  type = string
}

variable "runtime" {
  type    = string
  default = "nodejs22.x"
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
  type    = list(string)
  default = []
}

variable "environment" {
  type    = map(string)
  default = {}
}

variable "log_retention_days" {
  type    = number
  default = 365
}

variable "tracing_mode" {
  description = "X-Ray tracing: PassThrough | Active | null."
  type        = string
  default     = null
}

variable "vpc_config" {
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "role_arn" {
  type    = string
  default = null
}

variable "managed_policy_arns" {
  type    = list(string)
  default = []
}

# Lambda Function URL (used by the streaming `chat` handler).
variable "function_url" {
  description = "Optional Function URL config. null = no URL. invoke_mode RESPONSE_STREAM enables streaming."
  type = object({
    authorization_type = optional(string, "AWS_IAM")
    invoke_mode        = optional(string, "BUFFERED")
    cors_allow_origins = optional(list(string), [])
  })
  default = null
}
