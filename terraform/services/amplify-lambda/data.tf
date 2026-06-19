# Shared config from SSM (mirrors the ${ssm:/amplify/<stage>/...} references).
data "aws_ssm_parameter" "app_arn_name" {
  name = "${var.ssm_shared_path}/APP_ARN_NAME"
}
data "aws_ssm_parameter" "pandoc_layer_arn" {
  name = "${var.ssm_shared_path}/PANDOC_LAMBDA_LAYER_ARN"
}
data "aws_ssm_parameter" "api_gateway_max_timeout_ms" {
  name = "${var.ssm_shared_path}/API_GATEWAY_MAX_TIMEOUT_MS"
}

# ---- Cross-service params are now passed in as producer module-output variables
# (var.chat_billing_params, var.admin_params, var.object_access_params,
# var.amplify_js_params, var.embedding_params, var.lambda_ops_params,
# var.data_disclosure_params) instead of being read from SSM here.
