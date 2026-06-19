variable "stage" { type = string }
variable "region" { type = string }
variable "account_id" { type = string }
variable "partition" { type = string }
variable "name_prefix" { type = string } # amplify-<dep_name>
variable "dep_name" { type = string }

variable "rest_api_id" { type = string }
variable "rest_api_root_resource_id" { type = string }

variable "ssm_shared_path" { type = string }
variable "ssm_base_path" { type = string }

variable "shared_env" {
  type = map(string)
}

# Bedrock AgentCore web search (opt-in; mirrors the stage-var flags).
variable "web_search_agentcore_enabled" {
  type    = bool
  default = false
}
variable "web_search_agentcore_autoenable" {
  type    = bool
  default = false
}
variable "web_search_agentcore_region" {
  type    = string
  default = "us-east-1"
}

variable "lambda_params" { type = map(string) }
variable "object_access_params" { type = map(string) }
variable "chat_billing_params" { type = map(string) }
variable "amplify_js_params" { type = map(string) }
