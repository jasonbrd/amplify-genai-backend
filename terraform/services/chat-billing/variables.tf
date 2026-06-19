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

variable "lambda_params" { type = map(string) }
variable "admin_params" { type = map(string) }
variable "object_access_params" { type = map(string) }
variable "amplify_js_params" { type = map(string) }
variable "lambda_ops_params" { type = map(string) }
