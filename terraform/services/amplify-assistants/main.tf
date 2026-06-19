locals {
  service_name = "${var.name_prefix}-assistants"
  src_dir      = "${path.module}/../../../amplify-assistants"
  build_dir    = "${path.root}/build/amplify-assistants"

  # Local resources
  ast_code_interpreter_table    = "${local.service_name}-${var.stage}-code-interpreter-assistants"
  ast_lookup_table              = "${local.service_name}-${var.stage}-assistant-lookup"
  ast_thread_runs_table         = "${local.service_name}-${var.stage}-assistant-thread-runs"
  ast_threads_table             = "${local.service_name}-${var.stage}-assistant-threads"
  assistants_aliases_table      = "${local.service_name}-${var.stage}-assistant-aliases"
  assistants_table              = "${local.service_name}-${var.stage}-assistants"
  layered_assistants_table      = "${local.service_name}-${var.stage}-layered-assistants"
  group_ast_conversations_table = "${local.service_name}-${var.stage}-group-assistant-conversations"
  code_interpreter_files_bucket = "${local.service_name}-${var.stage}-code-interpreter-files"
  group_conversations_bucket    = "${local.service_name}-${var.stage}-group-conversations-content"
  policy_name                   = "${local.service_name}-${var.stage}-managed-policy"

  # Cross-service: assistants-api uploadIntegrationFiles function (invoke target).
  upload_integration_files_arn = "arn:${var.partition}:lambda:${var.region}:${var.account_id}:function:${var.name_prefix}-assistants-api-${var.stage}-uploadIntegrationFiles"

  published_params = {
    ASSISTANT_CODE_INTERPRETER_DYNAMODB_TABLE     = local.ast_code_interpreter_table
    ASSISTANT_LOOKUP_DYNAMODB_TABLE               = local.ast_lookup_table
    ASSISTANT_THREAD_RUNS_DYNAMODB_TABLE          = local.ast_thread_runs_table
    ASSISTANT_THREADS_DYNAMODB_TABLE              = local.ast_threads_table
    ASSISTANTS_ALIASES_DYNAMODB_TABLE             = local.assistants_aliases_table
    ASSISTANTS_DYNAMODB_TABLE                     = local.assistants_table
    LAYERED_ASSISTANTS_DYNAMODB_TABLE             = local.layered_assistants_table
    GROUP_ASSISTANT_CONVERSATIONS_DYNAMO_TABLE    = local.group_ast_conversations_table
    S3_GROUP_ASSISTANT_CONVERSATIONS_BUCKET_NAME  = local.group_conversations_bucket
    ASSISTANTS_CODE_INTERPRETER_FILES_BUCKET_NAME = local.code_interpreter_files_bucket
    ASSISTANT_LAMBDA_MANAGED_POLICY               = local.policy_name
  }

  extended_timeout_fns = toset(["create_ast", "chat_code_int_ast"])

  functions = {
    remove_astp_perms           = { handler = "service/core.remove_shared_ast_permissions", timeout = 30, memory_size = 1024, path = "assistant/remove_astp_permissions", method = "POST", cors = true }
    create_ast                  = { handler = "service/core.create_assistant", timeout = 900, memory_size = 1024, path = "assistant/create", method = "POST", cors = true }
    list_asts                   = { handler = "service/core.list_assistants", timeout = 30, memory_size = 1024, path = "assistant/list", method = "GET", cors = true }
    share_ast                   = { handler = "service/core.share_assistant", timeout = 30, memory_size = 1024, path = "assistant/share", method = "POST", cors = true }
    request_access_to_astp      = { handler = "service/core.request_assistant_to_public_ast", timeout = 30, memory_size = 1024, path = "assistant/request_access", method = "POST", cors = true }
    validate_ast_id             = { handler = "service/core.validate_assistant_id", timeout = 30, memory_size = 1024, path = "assistant/validate/assistant_id", method = "POST", cors = true }
    delete_ast                  = { handler = "service/core.delete_assistant", timeout = 30, memory_size = 1024, path = "assistant/delete", method = "POST", cors = true }
    create_layered_ast          = { handler = "service/layered_assistants.create_or_update_layered_assistant", timeout = 30, memory_size = 1024, path = "assistant/layered/create_or_update", method = "POST", cors = true }
    list_layered_asts           = { handler = "service/layered_assistants.list_layered_assistants", timeout = 30, memory_size = 1024, path = "assistant/layered/list", method = "GET", cors = true }
    delete_layered_ast          = { handler = "service/layered_assistants.delete_layered_assistant", timeout = 30, memory_size = 1024, path = "assistant/layered/delete", method = "POST", cors = true }
    download_code_int_file      = { handler = "openaiazure/assistant.get_presigned_url_code_interpreter", timeout = 6, memory_size = 1024, path = "assistant/files/download/codeinterpreter", method = "POST", cors = true }
    create_code_int_ast         = { handler = "openaiazure/assistant.create_code_interpreter_assistant", timeout = 30, memory_size = 1024, path = "assistant/create/codeinterpreter", method = "POST", cors = true }
    chat_code_int_ast           = { handler = "openaiazure/assistant.chat_with_code_interpreter", timeout = 300, memory_size = 1024, path = "assistant/chat/codeinterpreter", method = "POST", cors = true }
    delete_ast_thread           = { handler = "openaiazure/assistant.delete_assistant_thread", timeout = 6, memory_size = 1024, path = "assistant/openai/thread/delete", method = "DELETE", cors = true }
    delete_ast_open_ai          = { handler = "openaiazure/assistant.delete_assistant", timeout = 6, memory_size = 1024, path = "assistant/openai/delete", method = "DELETE", cors = true }
    get_group_ast_conversations = { handler = "service/group_ast_data.get_group_assistant_conversations", timeout = 30, memory_size = 1024, path = "assistant/get_group_assistant_conversations", method = "POST", cors = true }
    get_group_convs_data        = { handler = "service/group_ast_data.get_group_conversations_data", timeout = 30, memory_size = 1024, path = "assistant/get_group_conversations_data", method = "POST", cors = true }
    get_astg_system_user        = { handler = "service/group_ast_data.retrieve_astg_for_system_use", timeout = 6, memory_size = 1024, path = "assistant/get/system_user", method = "GET", cors = true }
    get_group_ast_dashboards    = { handler = "service/group_ast_data.get_group_assistant_dashboards", timeout = 30, memory_size = 1024, path = "assistant/get_group_assistant_dashboards", method = "POST", cors = true }
    save_user_rating            = { handler = "service/group_ast_data.save_user_rating", timeout = 30, memory_size = 1024, path = "assistant/save_user_rating", method = "POST", cors = true }
    lookup_ast_path             = { handler = "service/standalone_ast_path.lookup_assistant_path", timeout = 30, memory_size = 1024, path = "assistant/lookup", method = "POST", cors = true }
    add_ast_path                = { handler = "service/standalone_ast_path.add_assistant_path", timeout = 30, memory_size = 1024, path = "assistant/add_path", method = "POST", cors = true }
    scrape_website              = { handler = "service/scrape_websites.scrape_website", timeout = 300, memory_size = 1024, path = "assistant/scrape_website", method = "POST", cors = true }
    rescan_websites             = { handler = "service/scrape_websites.rescan_websites", timeout = 300, memory_size = 1024, path = "assistant/rescan_websites", method = "POST", cors = true }
    extract_sitemap_urls        = { handler = "service/scrape_websites.extract_sitemap_urls", timeout = 300, memory_size = 1024, path = "assistant/extract_sitemap_urls", method = "POST", cors = true }
    reprocess_drive_sources     = { handler = "service/drive_datasources.process_drive_sources", timeout = 300, memory_size = 1024, path = "assistant/process_drive_sources", method = "POST", cors = true }
    tools_op                    = { handler = "tools_ops.api_tools_handler", timeout = 30, memory_size = 1024, path = "assistant/register_ops", method = "POST", cors = true }
  }

  environment = merge(var.shared_env, {
    SERVICE_NAME                   = local.service_name
    ASSISTANTS_OPENAI_PROVIDER     = data.aws_ssm_parameter.openai_provider.value
    LLM_ENDPOINTS_SECRETS_NAME_ARN = data.aws_ssm_parameter.llm_secrets_arn.value
    LLM_ENDPOINTS_SECRETS_NAME     = data.aws_ssm_parameter.llm_secrets_name.value
    SECRETS_ARN_NAME               = data.aws_ssm_parameter.secrets_arn_name.value

    # Local
    ASSISTANT_CODE_INTERPRETER_DYNAMODB_TABLE     = local.ast_code_interpreter_table
    ASSISTANT_LOOKUP_DYNAMODB_TABLE               = local.ast_lookup_table
    ASSISTANT_THREAD_RUNS_DYNAMODB_TABLE          = local.ast_thread_runs_table
    ASSISTANT_THREADS_DYNAMODB_TABLE              = local.ast_threads_table
    ASSISTANTS_ALIASES_DYNAMODB_TABLE             = local.assistants_aliases_table
    ASSISTANTS_DYNAMODB_TABLE                     = local.assistants_table
    LAYERED_ASSISTANTS_DYNAMODB_TABLE             = local.layered_assistants_table
    GROUP_ASSISTANT_CONVERSATIONS_DYNAMO_TABLE    = local.group_ast_conversations_table
    ASSISTANTS_CODE_INTERPRETER_FILES_BUCKET_NAME = local.code_interpreter_files_bucket
    S3_GROUP_ASSISTANT_CONVERSATIONS_BUCKET_NAME  = local.group_conversations_bucket
    ASSISTANT_LAMBDA_MANAGED_POLICY               = local.policy_name

    # Cross-service (producer module outputs)
    ACCOUNTS_DYNAMO_TABLE          = var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]
    ADDITIONAL_CHARGES_TABLE       = var.chat_billing_params["ADDITIONAL_CHARGES_TABLE"]
    API_KEYS_DYNAMODB_TABLE        = var.object_access_params["API_KEYS_DYNAMODB_TABLE"]
    ASSISTANT_GROUPS_DYNAMO_TABLE  = var.object_access_params["ASSISTANT_GROUPS_DYNAMO_TABLE"]
    CHAT_USAGE_DYNAMO_TABLE        = var.lambda_params["CHAT_USAGE_DYNAMO_TABLE"]
    COGNITO_USERS_DYNAMODB_TABLE   = var.object_access_params["COGNITO_USERS_DYNAMODB_TABLE"]
    CRITICAL_ERRORS_SQS_QUEUE_NAME = var.admin_params["CRITICAL_ERRORS_SQS_QUEUE_NAME"]
    S3_CONSOLIDATION_BUCKET_NAME   = var.lambda_params["S3_CONSOLIDATION_BUCKET_NAME"]
    COST_CALCULATIONS_DYNAMO_TABLE = var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]
    ENV_VARS_TRACKING_TABLE        = var.lambda_params["ENV_VARS_TRACKING_TABLE"]
    HASH_FILES_DYNAMO_TABLE        = var.lambda_params["HASH_FILES_DYNAMO_TABLE"]
    MODEL_RATE_TABLE               = var.chat_billing_params["MODEL_RATE_TABLE"]
    OBJECT_ACCESS_DYNAMODB_TABLE   = var.object_access_params["OBJECT_ACCESS_DYNAMODB_TABLE"]
    OPS_DYNAMODB_TABLE             = var.lambda_ops_params["OPS_DYNAMODB_TABLE"]
    POLL_STATUS_TABLE              = var.lambda_params["POLL_STATUS_TABLE"]
    REQUEST_STATE_DYNAMO_TABLE     = var.amplify_js_params["REQUEST_STATE_DYNAMO_TABLE"]
    S3_IMAGE_INPUT_BUCKET_NAME     = var.lambda_params["S3_IMAGE_INPUT_BUCKET_NAME"]
    S3_RAG_INPUT_BUCKET_NAME       = var.lambda_params["S3_RAG_INPUT_BUCKET_NAME"]
    S3_SHARE_BUCKET_NAME           = var.lambda_params["S3_SHARE_BUCKET_NAME"]
    SHARES_DYNAMODB_TABLE          = var.lambda_params["SHARES_DYNAMODB_TABLE"]
  })
}

# ---- Shared SSM ----
data "aws_ssm_parameter" "openai_provider" {
  name = "${var.ssm_shared_path}/ASSISTANTS_OPENAI_PROVIDER"
}
data "aws_ssm_parameter" "llm_secrets_arn" {
  name = "${var.ssm_shared_path}/LLM_ENDPOINTS_SECRETS_NAME_ARN"
}
data "aws_ssm_parameter" "llm_secrets_name" {
  name = "${var.ssm_shared_path}/LLM_ENDPOINTS_SECRETS_NAME"
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

# ---- IAM ----
data "aws_iam_policy_document" "service" {
  statement {
    effect    = "Allow"
    actions   = ["lambda:InvokeFunction"]
    resources = [local.upload_integration_files_arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "dynamodb:Query", "dynamodb:Scan", "dynamodb:GetItem", "dynamodb:DeleteItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
      "s3:GetObject", "s3:PutObject", "s3:ListBucket",
    ]
    resources = [
      data.aws_ssm_parameter.llm_secrets_arn.value,
      "arn:${var.partition}:secretsmanager:${var.region}:*:secret:${data.aws_ssm_parameter.secrets_arn_name.value}*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["OBJECT_ACCESS_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["SHARES_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["API_KEYS_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["API_KEYS_DYNAMODB_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.ast_code_interpreter_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.chat_billing_params["ADDITIONAL_CHARGES_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.assistants_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.assistants_table}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.assistants_aliases_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.assistants_aliases_table}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.ast_threads_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.ast_threads_table}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.ast_thread_runs_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.ast_thread_runs_table}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.group_ast_conversations_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.group_ast_conversations_table}/*",
      "arn:${var.partition}:s3:::${local.code_interpreter_files_bucket}/*",
      "arn:${var.partition}:s3:::${var.lambda_params["S3_RAG_INPUT_BUCKET_NAME"]}/*",
      "arn:${var.partition}:s3:::${var.lambda_params["S3_IMAGE_INPUT_BUCKET_NAME"]}/*",
      "arn:${var.partition}:s3:::${local.group_conversations_bucket}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.ast_lookup_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.ast_lookup_table}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_ops_params["OPS_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_ops_params["OPS_DYNAMODB_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["COGNITO_USERS_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:s3:::${var.lambda_params["S3_CONSOLIDATION_BUCKET_NAME"]}",
      "arn:${var.partition}:s3:::${var.lambda_params["S3_CONSOLIDATION_BUCKET_NAME"]}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["CHAT_USAGE_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["CHAT_USAGE_DYNAMO_TABLE"]}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.chat_billing_params["MODEL_RATE_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.chat_billing_params["MODEL_RATE_TABLE"]}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["POLL_STATUS_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["POLL_STATUS_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.amplify_js_params["REQUEST_STATE_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.layered_assistants_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.layered_assistants_table}/*",
    ]
  }

  statement {
    effect  = "Allow"
    actions = ["dynamodb:GetItem"]
    resources = [
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["HASH_FILES_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["HASH_FILES_DYNAMO_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["ASSISTANT_GROUPS_DYNAMO_TABLE"]}",
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["arn:${var.partition}:s3:::${var.lambda_params["S3_SHARE_BUCKET_NAME"]}"]
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
    actions   = ["ssm:PutParameter", "ssm:GetParameter"]
    resources = ["arn:${var.partition}:ssm:${var.region}:${var.account_id}:parameter${var.ssm_shared_path}/${local.service_name}/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = ["arn:${var.partition}:sqs:${var.region}:*:${var.admin_params["CRITICAL_ERRORS_SQS_QUEUE_NAME"]}"]
  }

  statement {
    effect    = "Allow"
    actions   = ["bedrock:GetKnowledgeBase"]
    resources = ["arn:${var.partition}:bedrock:${var.region}:${var.account_id}:knowledge-base/*"]
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

# ---- DynamoDB (no SSESpecification in original => AWS-owned key, no sse block;
# GroupAssistantConversations is the only one with SSEEnabled) ----
resource "aws_dynamodb_table" "ast_lookup" {
  name         = local.ast_lookup_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "astPath"
  attribute {
    name = "astPath"
    type = "S"
  }
  attribute {
    name = "assistantId"
    type = "S"
  }
  global_secondary_index {
    name            = "AssistantIdIndex"
    hash_key        = "assistantId"
    projection_type = "ALL"
  }
  point_in_time_recovery { enabled = true }
}

resource "aws_dynamodb_table" "assistants" {
  name         = local.assistants_table
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
    name = "name"
    type = "S"
  }
  attribute {
    name = "assistantId"
    type = "S"
  }
  attribute {
    name = "version"
    type = "N"
  }
  global_secondary_index {
    name            = "UserIndex"
    hash_key        = "user"
    projection_type = "ALL"
  }
  global_secondary_index {
    name            = "UserNameIndex"
    hash_key        = "user"
    range_key       = "name"
    projection_type = "ALL"
  }
  global_secondary_index {
    name            = "AssistantIdIndex"
    hash_key        = "assistantId"
    range_key       = "version"
    projection_type = "ALL"
  }
  point_in_time_recovery { enabled = true }
}

resource "aws_dynamodb_table" "assistants_aliases" {
  name         = local.assistants_aliases_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user"
  range_key    = "assistantId"
  attribute {
    name = "assistantId"
    type = "S"
  }
  attribute {
    name = "user"
    type = "S"
  }
  attribute {
    name = "createdAt"
    type = "S"
  }
  global_secondary_index {
    name            = "AssistantIdIndex"
    hash_key        = "assistantId"
    range_key       = "user"
    projection_type = "ALL"
  }
  global_secondary_index {
    name            = "UserIndex"
    hash_key        = "user"
    range_key       = "createdAt"
    projection_type = "ALL"
  }
  point_in_time_recovery { enabled = true }
}

resource "aws_dynamodb_table" "layered_assistants" {
  name         = local.layered_assistants_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "assistantId"
  attribute {
    name = "assistantId"
    type = "S"
  }
  attribute {
    name = "createdBy"
    type = "S"
  }
  attribute {
    name = "updatedAt"
    type = "S"
  }
  global_secondary_index {
    name            = "CreatedByIndex"
    hash_key        = "createdBy"
    range_key       = "updatedAt"
    projection_type = "ALL"
  }
  point_in_time_recovery { enabled = true }
}

resource "aws_dynamodb_table" "ast_threads" {
  name         = local.ast_threads_table
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
    name = "name"
    type = "S"
  }
  global_secondary_index {
    name            = "UserIndex"
    hash_key        = "user"
    projection_type = "ALL"
  }
  global_secondary_index {
    name            = "UserNameIndex"
    hash_key        = "user"
    range_key       = "name"
    projection_type = "ALL"
  }
  point_in_time_recovery { enabled = true }
}

resource "aws_dynamodb_table" "ast_thread_runs" {
  name         = local.ast_thread_runs_table
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
  global_secondary_index {
    name            = "UserIndex"
    hash_key        = "user"
    projection_type = "ALL"
  }
  point_in_time_recovery { enabled = true }
}

resource "aws_dynamodb_table" "ast_code_interpreter" {
  name         = local.ast_code_interpreter_table
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
  global_secondary_index {
    name            = "UserIndex"
    hash_key        = "user"
    projection_type = "ALL"
  }
  point_in_time_recovery { enabled = true }
}

resource "aws_dynamodb_table" "group_ast_conversations" {
  name         = local.group_ast_conversations_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "conversationId"
  attribute {
    name = "conversationId"
    type = "S"
  }
  attribute {
    name = "assistantId"
    type = "S"
  }
  global_secondary_index {
    name            = "AssistantIdIndex"
    hash_key        = "assistantId"
    projection_type = "ALL"
  }
  point_in_time_recovery { enabled = true }
  server_side_encryption { enabled = true }
}

# ---- S3 ----
resource "aws_s3_bucket" "code_interpreter_files" {
  bucket = local.code_interpreter_files_bucket
}

resource "aws_s3_bucket_cors_configuration" "code_interpreter_files" {
  bucket = aws_s3_bucket.code_interpreter_files.id
  cors_rule {
    allowed_origins = ["*"]
    allowed_methods = ["GET"]
    allowed_headers = ["*"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "code_interpreter_files" {
  bucket = aws_s3_bucket.code_interpreter_files.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket" "group_conversations" {
  bucket = local.group_conversations_bucket
  lifecycle {
    prevent_destroy = true # DeletionPolicy: Retain
  }
}

resource "aws_s3_bucket_cors_configuration" "group_conversations" {
  bucket = aws_s3_bucket.group_conversations.id
  cors_rule {
    allowed_origins = ["*"]
    allowed_methods = ["GET", "PUT"]
    allowed_headers = ["*"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "group_conversations" {
  bucket = aws_s3_bucket.group_conversations.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ---- SSM publish (replaces this service's own parameter_store populator) ----
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
  package_path     = module.package.package_path
  source_code_hash = module.package.source_code_hash
  runtime          = "python3.11"
  timeout          = each.value.timeout
  memory_size      = each.value.memory_size
  layer_arns       = []
  environment      = local.environment
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
