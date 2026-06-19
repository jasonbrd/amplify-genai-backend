variable "stage" { type = string }
variable "region" { type = string }
variable "account_id" { type = string }
variable "partition" { type = string }
variable "name_prefix" { type = string } # amplify-<dep_name>

variable "rest_api_id" { type = string }
variable "rest_api_root_resource_id" { type = string }

variable "ssm_shared_path" { type = string } # /amplify/<stage>
variable "ssm_base_path" { type = string }   # /amplify/<stage>/amplify-<dep_name>

variable "shared_env" {
  type = map(string)
}

variable "api_gateway_max_timeout_ms" {
  description = "Integration timeout (ms) applied to the long-running routes that the retired ApiGatewayTimeoutConfig custom resource used to patch. null = AWS default (29s). >29000 requires an API GW service-quota increase."
  type        = number
  default     = null
}

variable "lambda_params" { type = map(string) }
variable "chat_billing_params" { type = map(string) }
variable "admin_params" { type = map(string) }
variable "amplify_js_params" { type = map(string) }
