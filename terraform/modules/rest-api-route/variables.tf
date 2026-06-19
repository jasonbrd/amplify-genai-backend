variable "rest_api_id" {
  description = "ID of the externally-owned shared REST API."
  type        = string
}

variable "root_resource_id" {
  description = "Root resource ID of the externally-owned shared REST API."
  type        = string
}

variable "region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "create_deployment" {
  description = "After route changes, redeploy the shared (externally-owned) stage via `aws apigateway create-deployment`, mirroring how each Serverless stack redeployed. Requires the AWS CLI on the machine running terraform. Disable to centralize deployment elsewhere."
  type        = bool
  default     = true
}

variable "stage_name" {
  description = "API Gateway stage to redeploy when create_deployment is true."
  type        = string
  default     = ""
}

variable "routes" {
  description = <<-EOT
    All HTTP routes for ONE service. Passing them together lets the module create
    each path-segment resource exactly once (avoids collisions when routes share a
    parent path, e.g. data-disclosure/check and data-disclosure/save).

    - path:          path WITHOUT leading slash, e.g. "data-disclosure/check"
    - method:        GET | POST | PUT | DELETE | ...
    - invoke_arn:    Lambda invoke_arn for the AWS_PROXY integration
    - function_name: Lambda function name (for the invoke permission)
    - cors:          add a CORS OPTIONS mock on the path's resource
    - timeout_ms:    optional API GW integration timeout (replaces the
                     runtime_config_manager custom resource); null = AWS default
  EOT
  type = list(object({
    path          = string
    method        = string
    invoke_arn    = string
    function_name = string
    cors          = optional(bool, false)
    timeout_ms    = optional(number, null)
  }))
}
