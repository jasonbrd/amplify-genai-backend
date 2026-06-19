locals {
  service_name = "${var.name_prefix}-admin"
  src_dir      = "${path.module}/../../../amplify-lambda-admin"
  build_dir    = "${path.root}/build/amplify-lambda-admin"

  admin_table           = "${local.service_name}-${var.stage}-admin-configs"
  admin_logs_table      = "${local.service_name}-${var.stage}-admin-logs"
  critical_errors_table = "${local.service_name}-${var.stage}-critical-errors"
  critical_errors_queue = "${local.service_name}-${var.stage}-critical-errors"
  critical_errors_dlq   = "${local.service_name}-${var.stage}-critical-errors-dlq"
  critical_errors_topic = "${local.service_name}-${var.stage}-critical-errors-notifications"
  policy_name           = "${local.service_name}-${var.stage}-iam-policy"

  # Consumed by other services via the published_params module output (string
  # names only). The admin table stream ARN is a resource attribute, so it is
  # published to SSM separately (below) and kept out of the consumable output to
  # avoid a known-after-apply value rippling into consumers.
  published_params = {
    AMPLIFY_ADMIN_DYNAMODB_TABLE   = local.admin_table
    CRITICAL_ERRORS_SQS_QUEUE_NAME = local.critical_errors_queue
  }

  functions = {
    update_admin_config        = { handler = "service/core.update_configs", timeout = 30, memory_size = 1024, kind = "http", path = "amplifymin/configs/update", method = "POST", cors = true }
    get_admin_config           = { handler = "service/core.get_configs", timeout = 30, memory_size = 1024, kind = "http", path = "amplifymin/configs", method = "GET", cors = true }
    get_feature_flags          = { handler = "service/core.get_user_feature_flags", timeout = 20, memory_size = 1024, kind = "http", path = "amplifymin/feature_flags", method = "GET", cors = true }
    get_user_app_configs       = { handler = "service/core.get_user_app_configs", timeout = 10, memory_size = 1024, kind = "http", path = "amplifymin/user_app_configs", method = "GET", cors = true }
    get_pptx_templates         = { handler = "service/core.get_pptx_for_users", timeout = 10, memory_size = 1024, kind = "http", path = "amplifymin/pptx_templates", method = "GET", cors = true }
    delete_pptx_template       = { handler = "service/core.delete_pptx_by_admin", timeout = 10, memory_size = 1024, kind = "http", path = "amplifymin/pptx_templates/delete", method = "DELETE", cors = true }
    upload_pptx_template       = { handler = "service/core.generate_presigned_url_for_upload", timeout = 10, memory_size = 1024, kind = "http", path = "amplifymin/pptx_templates/upload", method = "POST", cors = true }
    authenticate_admin         = { handler = "service/core.verify_valid_admin", timeout = 10, memory_size = 1024, kind = "http", path = "amplifymin/auth", method = "POST", cors = true }
    get_user_amplify_groups    = { handler = "service/user_services.get_user_amplify_groups", timeout = 6, memory_size = 1024, kind = "http", path = "amplifymin/amplify_groups/list", method = "GET", cors = true }
    get_user_affiliated_groups = { handler = "service/user_services.get_user_affiliated_groups", timeout = 6, memory_size = 1024, kind = "http", path = "amplifymin/amplify_groups/affiliated", method = "GET", cors = true }
    is_member_of_amp_group     = { handler = "service/user_services.verify_is_in_amp_group", timeout = 300, memory_size = 1024, kind = "http", path = "amplifymin/verify_amp_member", method = "POST", cors = true }
    get_critical_errors        = { handler = "service/critical_error_tracker.get_critical_errors_admin", timeout = 30, memory_size = 1024, kind = "http", path = "amplifymin/critical_errors", method = "POST", cors = true }
    resolve_critical_error     = { handler = "service/critical_error_tracker.resolve_critical_error_admin", timeout = 10, memory_size = 1024, kind = "http", path = "amplifymin/critical_errors/resolve", method = "POST", cors = true }

    sync_assistant_admins           = { handler = "service/core.sync_assistant_admins", timeout = 900, memory_size = 1024, kind = "schedule", path = "", method = "", cors = false }
    notify_critical_error           = { handler = "service/critical_error_notifier.notify_critical_error", timeout = 30, memory_size = 1024, kind = "stream", path = "", method = "", cors = false }
    process_critical_error_from_sqs = { handler = "service/critical_error_processor.process_critical_error_from_sqs", timeout = 30, memory_size = 1024, kind = "sqs", path = "", method = "", cors = false }
    provision_agentcore_web_search  = { handler = "service/agentcore_web_search_provisioner.lambda_handler", timeout = 300, memory_size = 1024, kind = "none", path = "", method = "", cors = false }
  }

  http_functions = { for k, f in local.functions : k => f if f.kind == "http" }

  environment = merge(var.shared_env, {
    SERVICE_NAME = local.service_name

    ADMINS                     = data.aws_ssm_parameter.admins.value
    APP_ARN_NAME               = data.aws_ssm_parameter.app_arn_name.value
    LLM_ENDPOINTS_SECRETS_NAME = data.aws_ssm_parameter.llm_endpoints_secrets_name.value
    COGNITO_CLIENT_ID          = data.aws_ssm_parameter.cognito_client_id.value
    SECRETS_ARN_NAME           = data.aws_ssm_parameter.secrets_arn_name.value

    # AgentCore web search
    WEB_SEARCH_AGENTCORE_ENABLED      = tostring(var.web_search_agentcore_enabled)
    WEB_SEARCH_AGENTCORE_AUTOENABLE   = tostring(var.web_search_agentcore_autoenable)
    WEB_SEARCH_AGENTCORE_REGION       = var.web_search_agentcore_region
    WEB_SEARCH_AGENTCORE_GATEWAY_NAME = "amplify-${var.dep_name}-${var.stage}-web-search"
    AGENTCORE_GATEWAY_ROLE_ARN        = aws_iam_role.agentcore_gateway.arn

    # Local
    AMPLIFY_ADMIN_DYNAMODB_TABLE      = local.admin_table
    AMPLIFY_ADMIN_LOGS_DYNAMODB_TABLE = local.admin_logs_table
    CRITICAL_ERRORS_DYNAMODB_TABLE    = local.critical_errors_table
    CRITICAL_ERRORS_SQS_QUEUE_NAME    = local.critical_errors_queue
    CRITICAL_ERRORS_SNS_TOPIC_NAME    = local.critical_errors_topic
    CRITICAL_ERRORS_SNS_TOPIC_ARN     = aws_sns_topic.critical_errors.arn

    # Cross-service (SSM)
    ACCOUNTS_DYNAMO_TABLE            = var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]
    ADDITIONAL_CHARGES_TABLE         = var.chat_billing_params["ADDITIONAL_CHARGES_TABLE"]
    API_KEYS_DYNAMODB_TABLE          = var.object_access_params["API_KEYS_DYNAMODB_TABLE"]
    ASSISTANT_GROUPS_DYNAMO_TABLE    = var.object_access_params["ASSISTANT_GROUPS_DYNAMO_TABLE"]
    COGNITO_USERS_DYNAMODB_TABLE     = var.object_access_params["COGNITO_USERS_DYNAMODB_TABLE"]
    COST_CALCULATIONS_DYNAMO_TABLE   = var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]
    ENV_VARS_TRACKING_TABLE          = var.lambda_params["ENV_VARS_TRACKING_TABLE"]
    S3_CONVERSION_OUTPUT_BUCKET_NAME = var.lambda_params["S3_CONVERSION_OUTPUT_BUCKET_NAME"]
    S3_CONSOLIDATION_BUCKET_NAME     = var.lambda_params["S3_CONSOLIDATION_BUCKET_NAME"]
  })
}

# ---- Shared SSM ----
data "aws_ssm_parameter" "admins" {
  name = "${var.ssm_shared_path}/ADMINS"
}
data "aws_ssm_parameter" "app_arn_name" {
  name = "${var.ssm_shared_path}/APP_ARN_NAME"
}
data "aws_ssm_parameter" "llm_endpoints_secrets_name" {
  name = "${var.ssm_shared_path}/LLM_ENDPOINTS_SECRETS_NAME"
}
data "aws_ssm_parameter" "cognito_client_id" {
  name = "${var.ssm_shared_path}/COGNITO_CLIENT_ID"
}
data "aws_ssm_parameter" "secrets_arn_name" {
  name = "${var.ssm_shared_path}/SECRETS_ARN_NAME"
}

# ---- Packaging (vendored deps, no layer) ----
module "package" {
  source            = "../../modules/python-package"
  source_dir        = local.src_dir
  requirements_path = "${local.src_dir}/requirements.txt"
  build_dir         = local.build_dir
  runtime           = "python3.11"
  architecture      = "x86_64"
  dockerize         = true
}

# ---- SQS ----
resource "aws_sqs_queue" "critical_errors_dlq" {
  name                      = local.critical_errors_dlq
  message_retention_seconds = 1209600 # 14 days
}

resource "aws_sqs_queue" "critical_errors" {
  name                       = local.critical_errors_queue
  visibility_timeout_seconds = 180    # 6x Lambda timeout
  message_retention_seconds  = 345600 # 4 days
  receive_wait_time_seconds  = 20     # long polling
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.critical_errors_dlq.arn
    maxReceiveCount     = 3
  })
}

# ---- SNS ----
resource "aws_sns_topic" "critical_errors" {
  name              = local.critical_errors_topic
  display_name      = "Critical Error Notifications"
  kms_master_key_id = "alias/aws/sns"
}

# ---- DynamoDB ----
resource "aws_dynamodb_table" "admin_configs" {
  name             = local.admin_table
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "config_id"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"
  attribute {
    name = "config_id"
    type = "S"
  }
  point_in_time_recovery { enabled = true }
  server_side_encryption { enabled = true }
}

resource "aws_dynamodb_table" "admin_logs" {
  name         = local.admin_logs_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "log_id"
  attribute {
    name = "log_id"
    type = "S"
  }
  point_in_time_recovery { enabled = true }
  server_side_encryption { enabled = true }
}

resource "aws_dynamodb_table" "critical_errors" {
  name             = local.critical_errors_table
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "error_id"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "error_id"
    type = "S"
  }
  attribute {
    name = "status"
    type = "S"
  }
  attribute {
    name = "timestamp"
    type = "N"
  }
  attribute {
    name = "error_fingerprint"
    type = "S"
  }

  global_secondary_index {
    name            = "status-timestamp-index"
    hash_key        = "status"
    range_key       = "timestamp"
    projection_type = "ALL"
  }
  global_secondary_index {
    name            = "error-fingerprint-index"
    hash_key        = "error_fingerprint"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
  point_in_time_recovery { enabled = true }
  server_side_encryption { enabled = true }
}

# ---- IAM: AgentCore gateway service role ----
data "aws_iam_policy_document" "agentcore_gateway_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["bedrock-agentcore.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "agentcore_gateway" {
  name               = "${local.service_name}-${var.stage}-agentcore-gateway"
  assume_role_policy = data.aws_iam_policy_document.agentcore_gateway_assume.json
}

resource "aws_iam_role_policy" "agentcore_gateway" {
  name = "agentcore-web-search"
  role = aws_iam_role.agentcore_gateway.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "InvokeGateway"
        Effect   = "Allow"
        Action   = "bedrock-agentcore:InvokeGateway"
        Resource = "arn:${var.partition}:bedrock-agentcore:${var.web_search_agentcore_region}:${var.account_id}:gateway/*"
      },
      {
        Sid      = "InvokeWebSearch"
        Effect   = "Allow"
        Action   = "bedrock-agentcore:InvokeWebSearch"
        Resource = "arn:${var.partition}:bedrock-agentcore:${var.web_search_agentcore_region}:aws:tool/web-search.v1"
      },
    ]
  })
}

# ---- IAM: execution policy + role ----
data "aws_iam_policy_document" "service" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:Query", "dynamodb:Scan", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
      "s3:ListBucket", "s3:PutObject", "s3:DeleteObject", "s3:GetObject",
      "secretsmanager:GetSecretValue", "secretsmanager:PutSecretValue", "secretsmanager:UpdateSecretVersionStage",
      "sns:Publish", "sns:Subscribe", "sns:Unsubscribe", "sns:ListSubscriptionsByTopic",
      "sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes",
    ]
    resources = [
      "arn:${var.partition}:secretsmanager:us-east-1:*:secret:${data.aws_ssm_parameter.app_arn_name.value}*",
      "arn:${var.partition}:secretsmanager:us-east-1:*:secret:${data.aws_ssm_parameter.secrets_arn_name.value}*",
      "arn:${var.partition}:secretsmanager:us-east-1:*:secret:${data.aws_ssm_parameter.llm_endpoints_secrets_name.value}*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["API_KEYS_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["API_KEYS_DYNAMODB_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.admin_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.admin_logs_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.critical_errors_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.critical_errors_table}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:${var.account_id}:table/${local.critical_errors_table}/stream/*",
      "arn:${var.partition}:sns:${var.region}:${var.account_id}:${local.critical_errors_topic}",
      "arn:${var.partition}:sqs:${var.region}:*:${local.critical_errors_queue}",
      "arn:${var.partition}:sqs:${var.region}:*:${local.critical_errors_dlq}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["COGNITO_USERS_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:s3:::${var.lambda_params["S3_CONVERSION_OUTPUT_BUCKET_NAME"]}",
      "arn:${var.partition}:s3:::${var.lambda_params["S3_CONVERSION_OUTPUT_BUCKET_NAME"]}/*",
      "arn:${var.partition}:s3:::${var.lambda_params["S3_CONSOLIDATION_BUCKET_NAME"]}",
      "arn:${var.partition}:s3:::${var.lambda_params["S3_CONSOLIDATION_BUCKET_NAME"]}/*",
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["dynamodb:Scan"]
    resources = ["arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["ASSISTANT_GROUPS_DYNAMO_TABLE"]}"]
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
    actions   = ["ssm:GetParameter", "ssm:PutParameter", "ssm:DeleteParameter"]
    resources = ["arn:${var.partition}:ssm:${var.region}:${var.account_id}:parameter/tools/web_search/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["dynamodb:DescribeStream", "dynamodb:GetRecords", "dynamodb:GetShardIterator", "dynamodb:ListStreams"]
    resources = ["arn:${var.partition}:dynamodb:${var.region}:${var.account_id}:table/${local.critical_errors_table}/stream/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "bedrock-agentcore:CreateGateway", "bedrock-agentcore:UpdateGateway", "bedrock-agentcore:GetGateway",
      "bedrock-agentcore:ListGateways", "bedrock-agentcore:DeleteGateway",
      "bedrock-agentcore:CreateGatewayTarget", "bedrock-agentcore:UpdateGatewayTarget", "bedrock-agentcore:GetGatewayTarget",
      "bedrock-agentcore:ListGatewayTargets", "bedrock-agentcore:DeleteGatewayTarget",
      "bedrock-agentcore:CreateWorkloadIdentity", "bedrock-agentcore:GetWorkloadIdentity",
      "bedrock-agentcore:UpdateWorkloadIdentity", "bedrock-agentcore:DeleteWorkloadIdentity",
      "bedrock-agentcore:ListWorkloadIdentities",
    ]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.agentcore_gateway.arn]
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

# ---- SSM publish ----
module "ssm_publish" {
  source    = "../../modules/ssm-publish"
  base_path = "${var.ssm_shared_path}/${local.service_name}"
  # The stream ARN is a resource attribute (known after apply); it stays out of
  # the consumable published_params output but is still published to SSM so the
  # runtime / external consumers keep their existing contract.
  parameters = merge(local.published_params, {
    AMPLIFY_ADMIN_TABLE_STREAM_ARN = aws_dynamodb_table.admin_configs.stream_arn
  })
}

# ---- Functions ----
module "fn" {
  source   = "../../modules/python-lambda"
  for_each = local.functions

  function_name    = "${local.service_name}-${var.stage}-${each.key}"
  handler          = each.value.handler
  package_path     = module.package.package_path
  source_code_hash = module.package.source_code_hash
  runtime          = "python3.11"
  timeout          = each.value.timeout
  memory_size      = each.value.memory_size
  layer_arns       = []
  environment      = local.environment
  role_arn         = aws_iam_role.lambda.arn
}

# ---- HTTP routes ----
module "routes" {
  source           = "../../modules/rest-api-route"
  rest_api_id      = var.rest_api_id
  root_resource_id = var.rest_api_root_resource_id
  region           = var.region
  account_id       = var.account_id
  stage_name       = var.stage

  routes = [
    for k, f in local.http_functions : {
      path          = f.path
      method        = f.method
      invoke_arn    = module.fn[k].invoke_arn
      function_name = module.fn[k].function_name
      cors          = f.cors
    }
  ]
}

# ---- Scheduled task (sync_assistant_admins, rate(3 minutes)) ----
resource "aws_cloudwatch_event_rule" "sync_assistant_admins" {
  name                = "${local.service_name}-${var.stage}-sync-assistant-admins"
  schedule_expression = "rate(3 minutes)"
}

resource "aws_cloudwatch_event_target" "sync_assistant_admins" {
  rule = aws_cloudwatch_event_rule.sync_assistant_admins.name
  arn  = module.fn["sync_assistant_admins"].function_arn
}

resource "aws_lambda_permission" "sync_assistant_admins" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.fn["sync_assistant_admins"].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.sync_assistant_admins.arn
}

# ---- Event source mappings ----
# notify_critical_error <- AmplifyAdminCriticalErrors table stream
resource "aws_lambda_event_source_mapping" "notify_critical_error" {
  event_source_arn  = aws_dynamodb_table.critical_errors.stream_arn
  function_name     = module.fn["notify_critical_error"].function_arn
  starting_position = "LATEST"
  batch_size        = 10
  enabled           = true
}

# process_critical_error_from_sqs <- CriticalErrors queue
resource "aws_lambda_event_source_mapping" "process_critical_error_from_sqs" {
  event_source_arn                   = aws_sqs_queue.critical_errors.arn
  function_name                      = module.fn["process_critical_error_from_sqs"].function_arn
  batch_size                         = 10
  maximum_batching_window_in_seconds = 5
  function_response_types            = ["ReportBatchItemFailures"]
}
