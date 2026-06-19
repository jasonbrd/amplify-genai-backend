locals {
  service_name = "${var.name_prefix}-assistants-api"
  src_dir      = "${path.module}/../../../amplify-lambda-assistants-api"
  build_dir    = "${path.root}/build/amplify-lambda-assistants-api"

  job_results_bucket = "${local.service_name}-${var.stage}-job-results"
  job_status_table   = "${local.service_name}-${var.stage}-job-status"
  oauth_state_table  = "${local.service_name}-${var.stage}-oauth-state"
  oauth_user_table   = "${local.service_name}-${var.stage}-user-oauth-integrations"
  op_log_table       = "${local.service_name}-${var.stage}-op-log"
  policy_name        = "${local.service_name}-${var.stage}-iam-policy"

  oauth_encryption_parameter = "/${local.service_name}/${var.stage}/oauth/integrations/encryption"

  published_params = {
    OAUTH_USER_TABLE = local.oauth_user_table
  }

  oauth_env = { OAUTH_ENCRYPTION_PARAMETER = local.oauth_encryption_parameter }

  extended_timeout_fns = toset(["listIntegrationFiles", "uploadIntegrationFiles", "execute_custom_auto"])

  functions = {
    getSupportedIntegrations      = { handler = "integrations/oauth.get_supported_integrations", timeout = 30, memory_size = 1024, path = "integrations/list_supported", method = "GET", cors = false, extra_env = {} }
    listConnectedUserIntegrations = { handler = "integrations/oauth.list_connected_integrations", timeout = 30, memory_size = 1024, path = "integrations/oauth/user/list", method = "GET", cors = false, extra_env = local.oauth_env }
    listIntegrationFiles          = { handler = "integrations/drive_files.list_integration_files", timeout = 300, memory_size = 1024, path = "integrations/user/files", method = "POST", cors = false, extra_env = {} }
    uploadIntegrationFiles        = { handler = "integrations/drive_files.drive_files_to_data_sources", timeout = 700, memory_size = 1024, path = "integrations/user/files/upload", method = "POST", cors = false, extra_env = local.oauth_env }
    downloadIntegrationFile       = { handler = "integrations/drive_files.download_integration_file", timeout = 30, memory_size = 1024, path = "integrations/user/files/download", method = "POST", cors = false, extra_env = local.oauth_env }
    registerIntegrationSecret     = { handler = "integrations/oauth.regiser_secret", timeout = 30, memory_size = 1024, path = "integrations/oauth/register_secret", method = "POST", cors = false, extra_env = local.oauth_env }
    refreshIntegrationsToken      = { handler = "integrations/oauth.refresh_integration_tokens", timeout = 30, memory_size = 1024, path = "integrations/oauth/refresh_token", method = "POST", cors = false, extra_env = local.oauth_env }
    execute_custom_auto           = { handler = "service/core.execute_custom_auto", timeout = 300, memory_size = 1024, path = "assistant-api/execute-custom-auto", method = "POST", cors = true, extra_env = {} }
    get_job_result                = { handler = "service/core.get_job_result", timeout = 30, memory_size = 1024, path = "assistant-api/get-job-result", method = "POST", cors = true, extra_env = {} }
    set_job_result                = { handler = "service/core.update_job_result", timeout = 30, memory_size = 1024, path = "assistant-api/set-job-result", method = "POST", cors = true, extra_env = {} }
    startAuth                     = { handler = "integrations/oauth.start_auth", timeout = 30, memory_size = 1024, path = "integrations/oauth/start-auth", method = "POST", cors = false, extra_env = local.oauth_env }
    authCallback                  = { handler = "integrations/oauth.auth_callback", timeout = 30, memory_size = 1024, path = "integrations/oauth/callback", method = "GET", cors = false, extra_env = local.oauth_env }
    deleteUserIntegration         = { handler = "integrations/oauth.handle_delete_integration", timeout = 30, memory_size = 1024, path = "integrations/oauth/user/delete", method = "POST", cors = false, extra_env = {} }
    listMCPServers                = { handler = "integrations/mcp_servers.list_mcp_servers", timeout = 30, memory_size = 1024, path = "integrations/mcp/servers", method = "GET", cors = false, extra_env = {} }
    addMCPServer                  = { handler = "integrations/mcp_servers.add_mcp_server", timeout = 30, memory_size = 1024, path = "integrations/mcp/servers", method = "POST", cors = false, extra_env = {} }
    getMCPServer                  = { handler = "integrations/mcp_servers.get_mcp_server", timeout = 30, memory_size = 1024, path = "integrations/mcp/server/get", method = "POST", cors = false, extra_env = {} }
    updateMCPServer               = { handler = "integrations/mcp_servers.update_mcp_server", timeout = 30, memory_size = 1024, path = "integrations/mcp/server/update", method = "POST", cors = false, extra_env = {} }
    deleteMCPServer               = { handler = "integrations/mcp_servers.delete_mcp_server", timeout = 30, memory_size = 1024, path = "integrations/mcp/server/delete", method = "POST", cors = false, extra_env = {} }
    testMCPConnection             = { handler = "integrations/mcp_servers.test_mcp_connection", timeout = 30, memory_size = 1024, path = "integrations/mcp/servers/test", method = "POST", cors = false, extra_env = {} }
    getMCPServerTools             = { handler = "integrations/mcp_servers.get_mcp_server_tools", timeout = 30, memory_size = 1024, path = "integrations/mcp/server/tools", method = "POST", cors = false, extra_env = {} }
    refreshMCPServerTools         = { handler = "integrations/mcp_servers.refresh_mcp_server_tools", timeout = 30, memory_size = 1024, path = "integrations/mcp/server/refresh", method = "POST", cors = false, extra_env = {} }
    startMCPOAuth                 = { handler = "integrations/mcp_servers.start_mcp_oauth", timeout = 30, memory_size = 1024, path = "integrations/mcp/server/oauth/start", method = "POST", cors = true, extra_env = {} }
    mcpOAuthCallback              = { handler = "integrations/mcp_servers.mcp_oauth_callback", timeout = 30, memory_size = 1024, path = "integrations/mcp/server/oauth/callback", method = "GET", cors = false, extra_env = {} }
    mcpOAuthExchange              = { handler = "integrations/mcp_servers.mcp_oauth_exchange", timeout = 30, memory_size = 1024, path = "integrations/mcp/server/oauth/exchange", method = "POST", cors = true, extra_env = {} }
    disconnectMCPOAuth            = { handler = "integrations/mcp_servers.disconnect_mcp_oauth", timeout = 30, memory_size = 1024, path = "integrations/mcp/server/oauth/disconnect", method = "POST", cors = true, extra_env = {} }
    refreshMCPOAuthToken          = { handler = "integrations/mcp_servers.refresh_mcp_oauth_token", timeout = 30, memory_size = 1024, path = "integrations/mcp/server/oauth/refresh", method = "POST", cors = true, extra_env = {} }
  }

  environment = merge(var.shared_env, {
    SERVICE_NAME                       = local.service_name
    INTEGRATION_STAGE                  = var.stage
    OP_TRACING_ENABLED                 = "true"
    OP_TRACING_REQUEST_DETAILS_ENABLED = "true"
    OP_TRACING_RESULT_DETAILS_ENABLED  = "true"

    JOB_RESULTS_BUCKET  = local.job_results_bucket
    JOB_STATUS_TABLE    = local.job_status_table
    OAUTH_STATE_TABLE   = local.oauth_state_table
    OAUTH_USER_TABLE    = local.oauth_user_table
    OP_LOG_DYNAMO_TABLE = local.op_log_table

    ACCOUNTS_DYNAMO_TABLE          = var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]
    ADDITIONAL_CHARGES_TABLE       = var.chat_billing_params["ADDITIONAL_CHARGES_TABLE"]
    AMPLIFY_ADMIN_DYNAMODB_TABLE   = var.admin_params["AMPLIFY_ADMIN_DYNAMODB_TABLE"]
    API_KEYS_DYNAMODB_TABLE        = var.object_access_params["API_KEYS_DYNAMODB_TABLE"]
    ASSISTANTS_DYNAMODB_TABLE      = var.assistants_params["ASSISTANTS_DYNAMODB_TABLE"]
    COGNITO_USERS_DYNAMODB_TABLE   = var.object_access_params["COGNITO_USERS_DYNAMODB_TABLE"]
    COST_CALCULATIONS_DYNAMO_TABLE = var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]
    CRITICAL_ERRORS_SQS_QUEUE_NAME = var.admin_params["CRITICAL_ERRORS_SQS_QUEUE_NAME"]
    ENV_VARS_TRACKING_TABLE        = var.lambda_params["ENV_VARS_TRACKING_TABLE"]
    S3_CONSOLIDATION_BUCKET_NAME   = var.lambda_params["S3_CONSOLIDATION_BUCKET_NAME"]
    USER_STORAGE_TABLE             = var.lambda_params["USER_STORAGE_TABLE"]
  })
}

# ---- Packaging + deps layer (this service uses layer:true) ----
data "archive_file" "package" {
  type        = "zip"
  source_dir  = local.src_dir
  output_path = "${local.build_dir}/package.zip"
  excludes    = ["serverless.yml", "requirements.txt", "node_modules", "venv", ".serverless", "package", "__pycache__", ".gitignore"]
}

module "deps_layer" {
  source            = "../../modules/python-deps-layer"
  layer_name        = "${local.service_name}-${var.stage}-python-requirements"
  requirements_path = "${local.src_dir}/requirements.txt"
  runtime           = "python3.11"
  architecture      = "x86_64"
  build_dir         = "${local.build_dir}/layer"
  dockerize         = true
}

# ---- IAM ----
data "aws_iam_policy_document" "service" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:Query", "dynamodb:Scan", "dynamodb:GetItem", "dynamodb:PutItem",
      "dynamodb:UpdateItem", "dynamodb:DeleteItem",
      "s3:GetObject", "s3:PutObject", "s3:ListBucket", "s3:DeleteObject",
    ]
    resources = [
      "arn:${var.partition}:s3:::${local.job_results_bucket}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.oauth_state_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.oauth_user_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["API_KEYS_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["API_KEYS_DYNAMODB_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.admin_params["AMPLIFY_ADMIN_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:s3:::${var.lambda_params["S3_CONSOLIDATION_BUCKET_NAME"]}",
      "arn:${var.partition}:s3:::${var.lambda_params["S3_CONSOLIDATION_BUCKET_NAME"]}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["COGNITO_USERS_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["USER_STORAGE_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["USER_STORAGE_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.assistants_params["ASSISTANTS_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.assistants_params["ASSISTANTS_DYNAMODB_TABLE"]}/index/*",
    ]
  }

  statement {
    effect  = "Allow"
    actions = ["ssm:GetParameter", "ssm:PutParameter", "ssm:DeleteParameter", "ssm:GetParametersByPath"]
    resources = [
      "arn:${var.partition}:ssm:${var.region}:${var.account_id}:parameter/oauth/*",
      "arn:${var.partition}:ssm:${var.region}:${var.account_id}:parameter/tools/web_search/*",
    ]
  }

  statement {
    effect  = "Allow"
    actions = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey"]
    resources = [
      "arn:${var.partition}:kms:${var.region}:${var.account_id}:alias/aws/ssm",
      "arn:${var.partition}:kms:${var.region}:${var.account_id}:key/*",
    ]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ssm.${var.region}.amazonaws.com"]
    }
  }

  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameter", "ssm:DescribeParameters", "ssm:PutParameter"]
    resources = ["arn:${var.partition}:ssm:${var.region}:${var.account_id}:parameter${local.oauth_encryption_parameter}*"]
  }

  statement {
    effect  = "Allow"
    actions = ["dynamodb:Query", "dynamodb:Scan", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"]
    resources = [
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.job_status_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.op_log_table}",
    ]
  }

  statement {
    effect  = "Allow"
    actions = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:Query"]
    resources = [
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["ENV_VARS_TRACKING_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["ENV_VARS_TRACKING_TABLE"]}/index/*",
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = ["arn:${var.partition}:ssm:${var.region}:${var.account_id}:parameter${var.ssm_base_path}-*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = ["arn:${var.partition}:sqs:${var.region}:*:${var.admin_params["CRITICAL_ERRORS_SQS_QUEUE_NAME"]}"]
  }

  statement {
    effect    = "Allow"
    actions   = ["dynamodb:PutItem"]
    resources = ["arn:${var.partition}:dynamodb:${var.region}:*:table/${var.chat_billing_params["ADDITIONAL_CHARGES_TABLE"]}"]
  }
}

resource "aws_iam_policy" "service" {
  name   = local.policy_name
  policy = data.aws_iam_policy_document.service.json
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.service_name}-${var.stage}-${var.region}-lambdaRole"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:${var.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "service" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.service.arn
}

# ---- DynamoDB ----
resource "aws_dynamodb_table" "oauth_state" {
  name         = local.oauth_state_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "state"
  attribute {
    name = "state"
    type = "S"
  }
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
  point_in_time_recovery { enabled = true }
  server_side_encryption { enabled = true }
}

resource "aws_dynamodb_table" "oauth_user" {
  name         = local.oauth_user_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_integration"
  attribute {
    name = "user_integration"
    type = "S"
  }
  point_in_time_recovery { enabled = true }
  server_side_encryption { enabled = true }
}

resource "aws_dynamodb_table" "op_log" {
  name         = local.op_log_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user"
  range_key    = "timestamp"
  attribute {
    name = "user"
    type = "S"
  }
  attribute {
    name = "timestamp"
    type = "S"
  }
  point_in_time_recovery { enabled = true }
  server_side_encryption { enabled = true }
}

resource "aws_dynamodb_table" "job_status" {
  name         = local.job_status_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user"
  range_key    = "job_id"
  attribute {
    name = "user"
    type = "S"
  }
  attribute {
    name = "job_id"
    type = "S"
  }
  point_in_time_recovery { enabled = true }
  server_side_encryption { enabled = true }
}

# JobResultsBucket (no CORS/SSE specified in the original config).
resource "aws_s3_bucket" "job_results" {
  bucket = local.job_results_bucket
}

# ---- SSM publish ----
module "ssm_publish" {
  source     = "../../modules/ssm-publish"
  base_path  = "${var.ssm_shared_path}/${local.service_name}"
  parameters = local.published_params
}

# ---- Functions ----
module "fn" {
  source   = "../../modules/python-lambda"
  for_each = local.functions

  function_name    = "${local.service_name}-${var.stage}-${each.key}"
  handler          = each.value.handler
  package_path     = data.archive_file.package.output_path
  source_code_hash = data.archive_file.package.output_base64sha256
  runtime          = "python3.11"
  timeout          = each.value.timeout
  memory_size      = each.value.memory_size
  layer_arns       = [module.deps_layer.layer_arn]
  environment      = merge(local.environment, each.value.extra_env)
  role_arn         = aws_iam_role.lambda.arn
}

# ---- Routes ----
module "routes" {
  source           = "../../modules/rest-api-route"
  rest_api_id      = var.rest_api_id
  root_resource_id = var.rest_api_root_resource_id
  region           = var.region
  account_id       = var.account_id
  stage_name       = var.stage

  routes = [
    for k, f in local.functions : {
      path          = f.path
      method        = f.method
      invoke_arn    = module.fn[k].invoke_arn
      function_name = module.fn[k].function_name
      cors          = f.cors
      timeout_ms    = contains(local.extended_timeout_fns, k) ? var.api_gateway_max_timeout_ms : null
    }
  ]
}
