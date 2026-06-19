locals {
  service_name = "${var.name_prefix}-amplify-js"
  src_dir      = "${path.module}/../../../amplify-lambda-js"
  build_dir    = "${path.root}/build/amplify-lambda-js"

  policy_name = "${local.service_name}-${var.stage}-iam-policy"

  # NOTE: cost-calculations + chat-traces are named under the amplify-lambda
  # prefix (this is how the original serverless.yml names them), though the
  # amplify-js service owns/creates them.
  cost_calc_table         = "${var.name_prefix}-lambda-${var.stage}-cost-calculations"
  history_cost_calc_table = "${var.name_prefix}-lambda-${var.stage}-history-cost-calculations"
  trace_bucket            = "${var.name_prefix}-lambda-${var.stage}-chat-traces"

  datasource_registry_table   = "${local.service_name}-${var.stage}-datasource-registry"
  request_state_table         = "${local.service_name}-${var.stage}-request-state"
  skills_table                = "${local.service_name}-${var.stage}-skills"
  skill_shares_table          = "${local.service_name}-${var.stage}-skill-shares"
  conversation_analysis_queue = "${local.service_name}-${var.stage}-conversation-analysis-queue"
  conversation_analysis_dlq   = "${local.service_name}-${var.stage}-conversation-analysis-dlq"

  published_params = {
    COST_CALCULATIONS_DYNAMO_TABLE = local.cost_calc_table
    REQUEST_STATE_DYNAMO_TABLE     = local.request_state_table
  }

  # kind: http | url | sqs | none(streaming)
  functions = {
    chat_stream             = { handler = "index.streamHandler", timeout = 900, memory_size = 1024, kind = "none", path = "", method = "", cors = false }
    chat                    = { handler = "index.handler", timeout = 900, memory_size = 1024, kind = "url", path = "", method = "", cors = false }
    reset_billing           = { handler = "billing/reset.handler", timeout = 180, memory_size = 512, kind = "schedule", path = "", method = "", cors = false }
    mtd_cost_reporter       = { handler = "billing/mtd.handler", timeout = 30, memory_size = 128, kind = "http", path = "billing/mtd-cost", method = "POST", cors = true }
    api_key_user_cost       = { handler = "billing/mtd.apiKeyUserCostHandler", timeout = 30, memory_size = 128, kind = "http", path = "billing/api-key-user-cost", method = "POST", cors = true }
    billing_groups_costs    = { handler = "billing/mtd.billingGroupsCostsHandler", timeout = 60, memory_size = 256, kind = "http", path = "billing/billing-groups-costs", method = "POST", cors = true }
    list_all_user_mtd_costs = { handler = "billing/mtd.listAllUserMtdCostsHandler", timeout = 30, memory_size = 128, kind = "http", path = "billing/list-all-user-mtd-costs", method = "POST", cors = true }
    list_user_mtd_costs     = { handler = "billing/mtd.listUserMtdCostsHandler", timeout = 30, memory_size = 128, kind = "http", path = "billing/list-user-mtd-costs", method = "POST", cors = true }
    user_cost_history       = { handler = "billing/mtd.getUserCostHistoryHandler", timeout = 30, memory_size = 256, kind = "http", path = "billing/user-cost-history", method = "POST", cors = true }
    convo_analysis          = { handler = "groupassistants/conversationAnalysis.sqsProcessorHandler", timeout = 300, memory_size = 512, kind = "sqs", path = "", method = "", cors = false }
  }

  http_functions = { for k, f in local.functions : k => f if f.kind == "http" }

  environment = merge(var.shared_env, {
    NODE_OPTIONS = "--enable-source-maps"
    SERVICE_NAME = local.service_name
    DEP_REGION   = var.region

    BEDROCK_GUARDRAIL_ID           = data.aws_ssm_parameter.guardrail_id.value
    BEDROCK_GUARDRAIL_VERSION      = data.aws_ssm_parameter.guardrail_version.value
    COGNITO_CLIENT_ID              = data.aws_ssm_parameter.cognito_client_id.value
    COGNITO_USER_POOL_ID           = data.aws_ssm_parameter.cognito_user_pool_id.value
    LLM_ENDPOINTS_SECRETS_NAME_ARN = data.aws_ssm_parameter.llm_secrets_arn.value
    LLM_ENDPOINTS_SECRETS_NAME     = data.aws_ssm_parameter.llm_secrets_name.value
    SECRETS_ARN_NAME               = data.aws_ssm_parameter.secrets_arn_name.value

    # Local
    COST_CALCULATIONS_DYNAMO_TABLE         = local.cost_calc_table
    HISTORY_COST_CALCULATIONS_DYNAMO_TABLE = local.history_cost_calc_table
    DATASOURCE_REGISTRY_DYNAMO_TABLE       = local.datasource_registry_table
    LAMBDA_JS_IAM_POLICY_NAME              = local.policy_name
    REQUEST_STATE_DYNAMO_TABLE             = local.request_state_table
    SKILLS_DYNAMODB_TABLE                  = local.skills_table
    SKILL_SHARES_DYNAMODB_TABLE            = local.skill_shares_table
    TRACE_BUCKET_NAME                      = local.trace_bucket
    CONVERSATION_ANALYSIS_QUEUE_URL        = local.conversation_analysis_queue

    # Cross-service (SSM)
    ADDITIONAL_CHARGES_TABLE                     = var.chat_billing_params["ADDITIONAL_CHARGES_TABLE"]
    AMPLIFY_ADMIN_DYNAMODB_TABLE                 = var.admin_params["AMPLIFY_ADMIN_DYNAMODB_TABLE"]
    API_KEYS_DYNAMODB_TABLE                      = var.object_access_params["API_KEYS_DYNAMODB_TABLE"]
    ASSISTANT_GROUPS_DYNAMO_TABLE                = var.object_access_params["ASSISTANT_GROUPS_DYNAMO_TABLE"]
    ASSISTANT_LOOKUP_DYNAMODB_TABLE              = var.assistants_params["ASSISTANT_LOOKUP_DYNAMODB_TABLE"]
    ASSISTANTS_ALIASES_DYNAMODB_TABLE            = var.assistants_params["ASSISTANTS_ALIASES_DYNAMODB_TABLE"]
    ASSISTANTS_DYNAMODB_TABLE                    = var.assistants_params["ASSISTANTS_DYNAMODB_TABLE"]
    LAYERED_ASSISTANTS_DYNAMODB_TABLE            = var.assistants_params["LAYERED_ASSISTANTS_DYNAMODB_TABLE"]
    CHAT_USAGE_DYNAMO_TABLE                      = var.lambda_params["CHAT_USAGE_DYNAMO_TABLE"]
    COGNITO_USERS_DYNAMODB_TABLE                 = var.object_access_params["COGNITO_USERS_DYNAMODB_TABLE"]
    CRITICAL_ERRORS_SQS_QUEUE_NAME               = var.admin_params["CRITICAL_ERRORS_SQS_QUEUE_NAME"]
    ENV_VARS_TRACKING_TABLE                      = var.lambda_params["ENV_VARS_TRACKING_TABLE"]
    GROUP_ASSISTANT_CONVERSATIONS_DYNAMO_TABLE   = var.assistants_params["GROUP_ASSISTANT_CONVERSATIONS_DYNAMO_TABLE"]
    HASH_FILES_DYNAMO_TABLE                      = var.lambda_params["HASH_FILES_DYNAMO_TABLE"]
    MODEL_RATE_TABLE                             = var.chat_billing_params["MODEL_RATE_TABLE"]
    S3_CONSOLIDATION_BUCKET_NAME                 = var.lambda_params["S3_CONSOLIDATION_BUCKET_NAME"]
    S3_FILE_TEXT_BUCKET_NAME                     = var.lambda_params["S3_FILE_TEXT_BUCKET_NAME"]
    S3_GROUP_ASSISTANT_CONVERSATIONS_BUCKET_NAME = var.assistants_params["S3_GROUP_ASSISTANT_CONVERSATIONS_BUCKET_NAME"]
    S3_IMAGE_INPUT_BUCKET_NAME                   = var.lambda_params["S3_IMAGE_INPUT_BUCKET_NAME"]
    S3_RAG_INPUT_BUCKET_NAME                     = var.lambda_params["S3_RAG_INPUT_BUCKET_NAME"]
    AGENT_STATE_DYNAMODB_TABLE                   = var.agent_loop_params["AGENT_STATE_DYNAMODB_TABLE"]
    USER_STORAGE_TABLE                           = var.lambda_params["USER_STORAGE_TABLE"]
  })
}

# ---- Shared SSM ----
data "aws_ssm_parameter" "guardrail_id" { name = "${var.ssm_shared_path}/BEDROCK_GUARDRAIL_ID" }
data "aws_ssm_parameter" "guardrail_version" { name = "${var.ssm_shared_path}/BEDROCK_GUARDRAIL_VERSION" }
data "aws_ssm_parameter" "cognito_client_id" { name = "${var.ssm_shared_path}/COGNITO_CLIENT_ID" }
data "aws_ssm_parameter" "cognito_user_pool_id" { name = "${var.ssm_shared_path}/COGNITO_USER_POOL_ID" }
data "aws_ssm_parameter" "llm_secrets_arn" { name = "${var.ssm_shared_path}/LLM_ENDPOINTS_SECRETS_NAME_ARN" }
data "aws_ssm_parameter" "llm_secrets_name" { name = "${var.ssm_shared_path}/LLM_ENDPOINTS_SECRETS_NAME" }
data "aws_ssm_parameter" "secrets_arn_name" { name = "${var.ssm_shared_path}/SECRETS_ARN_NAME" }

# ---- Packaging (Node: zip source incl. node_modules; run `npm ci` first) ----
data "archive_file" "package" {
  type        = "zip"
  source_dir  = local.src_dir
  output_path = "${local.build_dir}/package.zip"
  excludes    = ["serverless.yml", ".serverless", ".git", "package", "__pycache__", ".gitignore", "local"]
}

# ---- IAM ----
data "aws_iam_policy_document" "bedrock" {
  statement {
    effect  = "Allow"
    actions = ["bedrock:InvokeModelWithResponseStream", "bedrock:InvokeModel"]
    resources = [
      "arn:${var.partition}:bedrock:*::foundation-model/*",
      "arn:${var.partition}:bedrock:*:${var.account_id}:inference-profile/*",
    ]
  }
}

resource "aws_iam_policy" "bedrock" {
  name   = "${local.service_name}-${var.stage}-bedrock-policy"
  policy = data.aws_iam_policy_document.bedrock.json
}

data "aws_iam_policy_document" "service" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue", "s3:GetObject", "s3:PutObject", "s3:ListBucket",
      "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:Query", "dynamodb:UpdateItem", "dynamodb:Scan",
      "sqs:SendMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ReceiveMessage",
      "bedrock:InvokeModelWithResponseStream", "bedrock:InvokeModel",
    ]
    resources = [
      data.aws_ssm_parameter.llm_secrets_arn.value,
      "arn:${var.partition}:secretsmanager:${var.region}:*:secret:${data.aws_ssm_parameter.secrets_arn_name.value}*",
      "arn:${var.partition}:s3:::${var.lambda_params["S3_FILE_TEXT_BUCKET_NAME"]}", "arn:${var.partition}:s3:::${var.lambda_params["S3_FILE_TEXT_BUCKET_NAME"]}/*",
      "arn:${var.partition}:s3:::${var.lambda_params["S3_IMAGE_INPUT_BUCKET_NAME"]}", "arn:${var.partition}:s3:::${var.lambda_params["S3_IMAGE_INPUT_BUCKET_NAME"]}/*",
      "arn:${var.partition}:s3:::${local.trace_bucket}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["ASSISTANT_GROUPS_DYNAMO_TABLE"]}", "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["ASSISTANT_GROUPS_DYNAMO_TABLE"]}/*",
      "arn:${var.partition}:s3:::${var.assistants_params["S3_GROUP_ASSISTANT_CONVERSATIONS_BUCKET_NAME"]}", "arn:${var.partition}:s3:::${var.assistants_params["S3_GROUP_ASSISTANT_CONVERSATIONS_BUCKET_NAME"]}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["CHAT_USAGE_DYNAMO_TABLE"]}", "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["CHAT_USAGE_DYNAMO_TABLE"]}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["API_KEYS_DYNAMODB_TABLE"]}", "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["API_KEYS_DYNAMODB_TABLE"]}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.request_state_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["HASH_FILES_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.cost_calc_table}", "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.cost_calc_table}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.history_cost_calc_table}", "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.history_cost_calc_table}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.chat_billing_params["MODEL_RATE_TABLE"]}", "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.chat_billing_params["MODEL_RATE_TABLE"]}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.assistants_params["GROUP_ASSISTANT_CONVERSATIONS_DYNAMO_TABLE"]}", "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.assistants_params["GROUP_ASSISTANT_CONVERSATIONS_DYNAMO_TABLE"]}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.admin_params["AMPLIFY_ADMIN_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:bedrock:*::foundation-model/*",
      "arn:${var.partition}:bedrock:*:${var.account_id}:inference-profile/*",
      "arn:${var.partition}:s3:::${var.lambda_params["S3_CONSOLIDATION_BUCKET_NAME"]}", "arn:${var.partition}:s3:::${var.lambda_params["S3_CONSOLIDATION_BUCKET_NAME"]}/*",
      "arn:${var.partition}:sqs:${var.region}:${var.account_id}:${local.conversation_analysis_queue}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["COGNITO_USERS_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["USER_STORAGE_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.skills_table}", "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.skills_table}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.skill_shares_table}", "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.skill_shares_table}/*",
    ]
  }

  statement {
    effect  = "Allow"
    actions = ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:Scan"]
    resources = [
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.assistants_params["ASSISTANTS_ALIASES_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.assistants_params["ASSISTANTS_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.assistants_params["ASSISTANTS_DYNAMODB_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.agent_loop_params["AGENT_STATE_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.assistants_params["ASSISTANT_LOOKUP_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.assistants_params["ASSISTANT_LOOKUP_DYNAMODB_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.assistants_params["LAYERED_ASSISTANTS_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.assistants_params["LAYERED_ASSISTANTS_DYNAMODB_TABLE"]}/index/*",
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["dynamodb:GetItem"]
    resources = ["arn:${var.partition}:dynamodb:${var.region}:*:table/${local.datasource_registry_table}"]
  }

  statement {
    effect  = "Allow"
    actions = ["dynamodb:DeleteItem"]
    resources = [
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.request_state_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.skills_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.skill_shares_table}",
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["arn:${var.partition}:s3:::${var.lambda_params["S3_RAG_INPUT_BUCKET_NAME"]}/*"]
  }

  statement {
    effect  = "Allow"
    actions = ["bedrock:InvokeGuardrail", "bedrock:ApplyGuardrail"]
    resources = [
      "arn:${var.partition}:bedrock:*:${var.account_id}:guardrail/*",
      "arn:${var.partition}:bedrock:*:${var.account_id}:guardrail-profile/*",
    ]
  }

  statement {
    effect  = "Allow"
    actions = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:Query"]
    resources = [
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["ENV_VARS_TRACKING_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["ENV_VARS_TRACKING_TABLE"]}/index/*",
      aws_sqs_queue.conversation_analysis.arn,
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["dynamodb:PutItem"]
    resources = ["arn:${var.partition}:dynamodb:${var.region}:*:table/${var.chat_billing_params["ADDITIONAL_CHARGES_TABLE"]}"]
  }

  statement {
    effect  = "Allow"
    actions = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = [
      "arn:${var.partition}:ssm:${var.region}:${var.account_id}:parameter${var.ssm_base_path}-*",
      "arn:${var.partition}:ssm:${var.region}:${var.account_id}:parameter/tools*",
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = ["arn:${var.partition}:sqs:${var.region}:*:${var.admin_params["CRITICAL_ERRORS_SQS_QUEUE_NAME"]}"]
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

resource "aws_iam_role_policy_attachment" "bedrock" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.bedrock.arn
}

# ---- DynamoDB tables (owned by amplify-js) ----
resource "aws_dynamodb_table" "request_state" {
  name         = local.request_state_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user"
  range_key    = "requestId"
  attribute {
    name = "requestId"
    type = "S"
  }
  attribute {
    name = "user"
    type = "S"
  }
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
  point_in_time_recovery { enabled = true }
}

resource "aws_dynamodb_table" "datasource_registry" {
  name         = local.datasource_registry_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "type"
  attribute {
    name = "type"
    type = "S"
  }
  point_in_time_recovery { enabled = true }
}

resource "aws_dynamodb_table" "skills" {
  name         = local.skills_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  attribute {
    name = "id"
    type = "S"
  }
  attribute {
    name = "user"
    type = "S"
  }
  attribute {
    name = "isPublic"
    type = "S"
  }
  global_secondary_index {
    name            = "user-index"
    hash_key        = "user"
    projection_type = "ALL"
  }
  global_secondary_index {
    name            = "public-skills-index"
    hash_key        = "isPublic"
    projection_type = "ALL"
  }
  point_in_time_recovery { enabled = true }
}

resource "aws_dynamodb_table" "skill_shares" {
  name         = local.skill_shares_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "shareId"
  attribute {
    name = "shareId"
    type = "S"
  }
  attribute {
    name = "sharedWith"
    type = "S"
  }
  attribute {
    name = "skillId"
    type = "S"
  }
  global_secondary_index {
    name            = "sharedWith-index"
    hash_key        = "sharedWith"
    projection_type = "ALL"
  }
  global_secondary_index {
    name            = "skillId-index"
    hash_key        = "skillId"
    projection_type = "ALL"
  }
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
  point_in_time_recovery { enabled = true }
}

resource "aws_dynamodb_table" "cost_calculations" {
  name         = local.cost_calc_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  range_key    = "accountInfo"
  attribute {
    name = "id"
    type = "S"
  }
  attribute {
    name = "accountInfo"
    type = "S"
  }
  attribute {
    name = "record_type"
    type = "S"
  }
  global_secondary_index {
    name            = "record-type-user-index"
    hash_key        = "record_type"
    range_key       = "id"
    projection_type = "ALL"
  }
  point_in_time_recovery { enabled = true }
}

resource "aws_dynamodb_table" "history_cost_calculations" {
  name         = local.history_cost_calc_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userDate"
  range_key    = "accountInfo"
  attribute {
    name = "userDate"
    type = "S"
  }
  attribute {
    name = "accountInfo"
    type = "S"
  }
  attribute {
    name = "record_type"
    type = "S"
  }
  global_secondary_index {
    name            = "record-type-user-index"
    hash_key        = "record_type"
    range_key       = "userDate"
    projection_type = "ALL"
  }
  point_in_time_recovery { enabled = true }
}

# ---- S3 + SQS ----
resource "aws_s3_bucket" "chat_traces" {
  bucket = local.trace_bucket
}

resource "aws_sqs_queue" "conversation_analysis_dlq" {
  name                      = local.conversation_analysis_dlq
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "conversation_analysis" {
  name                       = local.conversation_analysis_queue
  visibility_timeout_seconds = 360
  message_retention_seconds  = 1209600
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.conversation_analysis_dlq.arn
    maxReceiveCount     = 3
  })
}

# ---- SSM publish ----
module "ssm_publish" {
  source     = "../../modules/ssm-publish"
  base_path  = "${var.ssm_shared_path}/${local.service_name}"
  parameters = local.published_params
}

# ---- Functions ----
module "fn" {
  source   = "../../modules/node-lambda"
  for_each = local.functions

  function_name    = "${local.service_name}-${var.stage}-${each.key}"
  handler          = each.value.handler
  package_path     = data.archive_file.package.output_path
  source_code_hash = data.archive_file.package.output_base64sha256
  runtime          = "nodejs22.x"
  architecture     = "x86_64"
  timeout          = each.value.timeout
  memory_size      = each.value.memory_size
  environment      = local.environment
  role_arn         = aws_iam_role.lambda.arn
  tracing_mode     = "Active"

  function_url = each.value.kind == "url" ? {
    authorization_type = "NONE"
    invoke_mode        = "RESPONSE_STREAM"
    cors_allow_origins = ["*"]
  } : null
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

# ---- Scheduled task: reset_billing (daily midnight UTC) ----
resource "aws_cloudwatch_event_rule" "reset_billing" {
  name                = "${local.service_name}-${var.stage}-reset-billing"
  schedule_expression = "cron(0 0 * * ? *)"
}
resource "aws_cloudwatch_event_target" "reset_billing" {
  rule = aws_cloudwatch_event_rule.reset_billing.name
  arn  = module.fn["reset_billing"].function_arn
}
resource "aws_lambda_permission" "reset_billing" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = module.fn["reset_billing"].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.reset_billing.arn
}

# ---- SQS: convo_analysis ----
resource "aws_lambda_event_source_mapping" "convo_analysis" {
  event_source_arn                   = aws_sqs_queue.conversation_analysis.arn
  function_name                      = module.fn["convo_analysis"].function_arn
  batch_size                         = 1
  maximum_batching_window_in_seconds = 5
}
