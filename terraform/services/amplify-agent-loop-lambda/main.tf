locals {
  service_name = "${var.name_prefix}-agent-loop"
  src_dir      = "${path.module}/../../../amplify-agent-loop-lambda"
  build_dir    = "${path.root}/build/amplify-agent-loop-lambda"

  # Local resources
  agent_event_templates_table = "${local.service_name}-${var.stage}-agent-event-templates"
  agent_state_bucket          = "${local.service_name}-${var.stage}-agent-state"
  agent_state_table           = "${local.service_name}-${var.stage}-agent-state"
  email_settings_table        = "${local.service_name}-${var.stage}-email-allowed-senders"
  scheduled_tasks_logs_bucket = "${local.service_name}-${var.stage}-scheduled-tasks-logs"
  scheduled_tasks_table       = "${local.service_name}-${var.stage}-scheduled-tasks"
  workflow_templates_bucket   = "${local.service_name}-${var.stage}-workflow-templates"
  workflow_templates_table    = "${local.service_name}-${var.stage}-workflow-registry"
  raw_emails_bucket           = "${local.service_name}-${var.stage}-raw-emails"
  agent_queue                 = "${local.service_name}-${var.stage}-agent-queue"
  agent_dlq                   = "${local.service_name}-${var.stage}-agent-dlq"
  email_topic                 = "${local.service_name}-${var.stage}-email-topic"

  policy_name       = "${local.service_name}-${var.stage}-iam-policy-updated-v2"
  email_policy_name = "${local.service_name}-${var.stage}-email-processing-policy"

  notes_ingest_queue_arn = "arn:${var.partition}:sqs:${var.region}:${var.account_id}:amplify-notes-ingest-queue-${var.stage}"

  published_params = {
    AGENT_STATE_DYNAMODB_TABLE = local.agent_state_table
  }

  functions = {
    agentRouter             = { handler = "service/core.route", timeout = 900, memory_size = 1024, kind = "http", path = "vu-agent/{proxy+}", method = "POST", cors = false }
    agentEventProcessor     = { handler = "service/agent_queue.route_queue_event", timeout = 900, memory_size = 1024, kind = "sqs", path = "", method = "", cors = false }
    scheduledTasksProcessor = { handler = "scheduled_tasks_events/scheduled_tasks.execute_scheduled_tasks", timeout = 300, memory_size = 1024, kind = "schedule", path = "", method = "", cors = false }
    toolsEndpointLambda     = { handler = "service/core.get_builtin_tools", timeout = 30, memory_size = 4096, kind = "http", path = "vu-agent/tools", method = "GET", cors = true }
  }

  http_functions = { for k, f in local.functions : k => f if f.kind == "http" }

  environment = merge(var.shared_env, {
    SERVICE_NAME                    = local.service_name
    AGENT_QUEUE_URL                 = aws_sqs_queue.agent.url
    APP_ARN_NAME                    = data.aws_ssm_parameter.app_arn_name.value
    DEFAULT_SECRET_PARAMETER_PREFIX = "/agent"
    LLM_ENDPOINTS_SECRETS_NAME_ARN  = data.aws_ssm_parameter.llm_secrets_arn.value
    LLM_ENDPOINTS_SECRETS_NAME      = data.aws_ssm_parameter.llm_secrets_name.value
    ORGANIZATION_EMAIL_DOMAIN       = data.aws_ssm_parameter.org_email_domain.value
    SECRETS_ARN_NAME                = data.aws_ssm_parameter.secrets_arn_name.value

    # Local
    AGENT_EVENT_TEMPLATES_DYNAMODB_TABLE = local.agent_event_templates_table
    AGENT_STATE_BUCKET                   = local.agent_state_bucket
    AGENT_STATE_DYNAMODB_TABLE           = local.agent_state_table
    EMAIL_SETTINGS_DYNAMO_TABLE          = local.email_settings_table
    LAMBDA_AGENT_LOOP_IAM_POLICY_NAME    = local.policy_name
    SCHEDULED_TASKS_LOGS_BUCKET          = local.scheduled_tasks_logs_bucket
    SCHEDULED_TASKS_TABLE                = local.scheduled_tasks_table
    WORKFLOW_TEMPLATES_BUCKET            = local.workflow_templates_bucket
    WORKFLOW_TEMPLATES_TABLE             = local.workflow_templates_table
    RAW_EMAILS_BUCKET                    = local.raw_emails_bucket

    # Cross-service (SSM)
    ACCOUNTS_DYNAMO_TABLE             = var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]
    ADDITIONAL_CHARGES_TABLE          = var.chat_billing_params["ADDITIONAL_CHARGES_TABLE"]
    API_KEYS_DYNAMODB_TABLE           = var.object_access_params["API_KEYS_DYNAMODB_TABLE"]
    ASSISTANTS_ALIASES_DYNAMODB_TABLE = var.assistants_params["ASSISTANTS_ALIASES_DYNAMODB_TABLE"]
    ASSISTANTS_DYNAMODB_TABLE         = var.assistants_params["ASSISTANTS_DYNAMODB_TABLE"]
    CHAT_USAGE_DYNAMO_TABLE           = var.lambda_params["CHAT_USAGE_DYNAMO_TABLE"]
    COGNITO_USERS_DYNAMODB_TABLE      = var.object_access_params["COGNITO_USERS_DYNAMODB_TABLE"]
    CRITICAL_ERRORS_SQS_QUEUE_NAME    = var.admin_params["CRITICAL_ERRORS_SQS_QUEUE_NAME"]
    COST_CALCULATIONS_DYNAMO_TABLE    = var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]
    DB_CONNECTIONS_TABLE              = var.lambda_params["DB_CONNECTIONS_TABLE"]
    ENV_VARS_TRACKING_TABLE           = var.lambda_params["ENV_VARS_TRACKING_TABLE"]
    FILES_DYNAMO_TABLE                = var.lambda_params["FILES_DYNAMO_TABLE"]
    MODEL_RATE_TABLE                  = var.chat_billing_params["MODEL_RATE_TABLE"]
    OPS_DYNAMODB_TABLE                = var.lambda_ops_params["OPS_DYNAMODB_TABLE"]
    REQUEST_STATE_DYNAMO_TABLE        = var.amplify_js_params["REQUEST_STATE_DYNAMO_TABLE"]
    S3_CONSOLIDATION_BUCKET_NAME      = var.lambda_params["S3_CONSOLIDATION_BUCKET_NAME"]
    S3_IMAGE_INPUT_BUCKET_NAME        = var.lambda_params["S3_IMAGE_INPUT_BUCKET_NAME"]
    S3_RAG_INPUT_BUCKET_NAME          = var.lambda_params["S3_RAG_INPUT_BUCKET_NAME"]
    USER_TAGS_DYNAMO_TABLE            = var.lambda_params["USER_TAGS_DYNAMO_TABLE"]

    # Optional (Amplify Notes / AI Scheduler) — present as SSM params (may be empty).
    NOTES_EMAIL                = data.aws_ssm_parameter.notes_email.value
    NOTES_INGEST_QUEUE_URL     = data.aws_ssm_parameter.notes_ingest_queue_url.value
    S3_NOTES_RAW_FILES_BUCKET  = data.aws_ssm_parameter.notes_raw_files_bucket.value
    AI_SCHEDULER_STORAGE_TABLE = data.aws_ssm_parameter.ai_scheduler_storage_table.value
  })
}

# ---- Shared SSM ----
data "aws_ssm_parameter" "app_arn_name" { name = "${var.ssm_shared_path}/APP_ARN_NAME" }
data "aws_ssm_parameter" "llm_secrets_arn" { name = "${var.ssm_shared_path}/LLM_ENDPOINTS_SECRETS_NAME_ARN" }
data "aws_ssm_parameter" "llm_secrets_name" { name = "${var.ssm_shared_path}/LLM_ENDPOINTS_SECRETS_NAME" }
data "aws_ssm_parameter" "org_email_domain" { name = "${var.ssm_shared_path}/ORGANIZATION_EMAIL_DOMAIN" }
data "aws_ssm_parameter" "secrets_arn_name" { name = "${var.ssm_shared_path}/SECRETS_ARN_NAME" }
data "aws_ssm_parameter" "notes_email" { name = "${var.ssm_shared_path}/NOTES_EMAIL" }
data "aws_ssm_parameter" "notes_ingest_queue_url" { name = "${var.ssm_shared_path}/NOTES_INGEST_QUEUE_URL" }
data "aws_ssm_parameter" "notes_raw_files_bucket" { name = "${var.ssm_shared_path}/S3_NOTES_RAW_FILES_BUCKET" }
data "aws_ssm_parameter" "ai_scheduler_storage_table" { name = "${var.ssm_shared_path}/AI_SCHEDULER_STORAGE_TABLE" }

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

# ---- SQS + SNS (email flow) ----
resource "aws_sqs_queue" "agent_dlq" {
  name                      = local.agent_dlq
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "agent" {
  name                       = local.agent_queue
  visibility_timeout_seconds = 910
  message_retention_seconds  = 1209600
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.agent_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sns_topic" "email" {
  name = local.email_topic
}

resource "aws_sns_topic_subscription" "email_to_queue" {
  topic_arn = aws_sns_topic.email.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.agent.arn
}

data "aws_iam_policy_document" "email_topic" {
  statement {
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.email.arn]
    principals {
      type        = "Service"
      identifiers = ["ses.amazonaws.com"]
    }
  }
}

resource "aws_sns_topic_policy" "email" {
  arn    = aws_sns_topic.email.arn
  policy = data.aws_iam_policy_document.email_topic.json
}

data "aws_iam_policy_document" "agent_queue" {
  statement {
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.agent.arn]
    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.email.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "agent" {
  queue_url = aws_sqs_queue.agent.id
  policy    = data.aws_iam_policy_document.agent_queue.json
}

# ---- DynamoDB ----
resource "aws_dynamodb_table" "agent_state" {
  name         = local.agent_state_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user"
  range_key    = "sessionId"
  attribute {
    name = "user"
    type = "S"
  }
  attribute {
    name = "sessionId"
    type = "S"
  }
  point_in_time_recovery { enabled = true }
}

resource "aws_dynamodb_table" "agent_event_templates" {
  name         = local.agent_event_templates_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user"
  range_key    = "tag"
  attribute {
    name = "user"
    type = "S"
  }
  attribute {
    name = "tag"
    type = "S"
  }
  point_in_time_recovery { enabled = true }
}

resource "aws_dynamodb_table" "email_settings" {
  name         = local.email_settings_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "email"
  range_key    = "tag"
  attribute {
    name = "email"
    type = "S"
  }
  attribute {
    name = "tag"
    type = "S"
  }
  point_in_time_recovery { enabled = true }
}

resource "aws_dynamodb_table" "workflow_templates" {
  name         = local.workflow_templates_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user"
  range_key    = "templateId"
  attribute {
    name = "user"
    type = "S"
  }
  attribute {
    name = "templateId"
    type = "S"
  }
  attribute {
    name = "isPublic"
    type = "N"
  }
  global_secondary_index {
    name            = "TemplateIdPublicIndex"
    hash_key        = "templateId"
    range_key       = "isPublic"
    projection_type = "ALL"
  }
  point_in_time_recovery { enabled = true }
}

resource "aws_dynamodb_table" "scheduled_tasks" {
  name         = local.scheduled_tasks_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user"
  range_key    = "taskId"
  attribute {
    name = "user"
    type = "S"
  }
  attribute {
    name = "taskId"
    type = "S"
  }
  attribute {
    name = "active"
    type = "N"
  }
  global_secondary_index {
    name            = "ActiveTasksIndex"
    hash_key        = "active"
    range_key       = "taskId"
    projection_type = "ALL"
  }
  point_in_time_recovery { enabled = true }
}

# ---- S3 ----
resource "aws_s3_bucket" "agent_state" {
  bucket = local.agent_state_bucket
}
resource "aws_s3_bucket_cors_configuration" "agent_state" {
  bucket = aws_s3_bucket.agent_state.id
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket" "workflow_templates" {
  bucket = local.workflow_templates_bucket
}
resource "aws_s3_bucket_cors_configuration" "workflow_templates" {
  bucket = aws_s3_bucket.workflow_templates.id
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket" "scheduled_tasks_logs" {
  bucket = local.scheduled_tasks_logs_bucket
}
resource "aws_s3_bucket_cors_configuration" "scheduled_tasks_logs" {
  bucket = aws_s3_bucket.scheduled_tasks_logs.id
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket" "raw_emails" {
  bucket = local.raw_emails_bucket
}
resource "aws_s3_bucket_public_access_block" "raw_emails" {
  bucket                  = aws_s3_bucket.raw_emails.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_lifecycle_configuration" "raw_emails" {
  bucket = aws_s3_bucket.raw_emails.id
  rule {
    id     = "DeleteOldEmails"
    status = "Enabled"
    filter {}
    expiration {
      days = 7
    }
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "raw_emails" {
  bucket = aws_s3_bucket.raw_emails.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
data "aws_iam_policy_document" "raw_emails" {
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.raw_emails.arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["ses.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [var.account_id]
    }
  }
}
resource "aws_s3_bucket_policy" "raw_emails" {
  bucket = aws_s3_bucket.raw_emails.id
  policy = data.aws_iam_policy_document.raw_emails.json
}

# ---- IAM ----
data "aws_iam_policy_document" "service" {
  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameter", "ssm:PutParameter"]
    resources = ["arn:${var.partition}:ssm:${var.region}:${var.account_id}:parameter/agent/*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "dynamodb:Query", "dynamodb:Scan", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem",
      "s3:GetObject", "s3:PutObject", "s3:ListObjects", "s3:ListBucket", "s3:DeleteObject",
    ]
    resources = [
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.assistants_params["ASSISTANTS_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.assistants_params["ASSISTANTS_DYNAMODB_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["DB_CONNECTIONS_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["DB_CONNECTIONS_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.assistants_params["ASSISTANTS_ALIASES_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.assistants_params["ASSISTANTS_ALIASES_DYNAMODB_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["API_KEYS_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["API_KEYS_DYNAMODB_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_ops_params["OPS_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_ops_params["OPS_DYNAMODB_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.agent_state_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.agent_state_table}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.agent_event_templates_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.agent_event_templates_table}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.email_settings_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.email_settings_table}/index/*",
      "arn:${var.partition}:s3:::${local.agent_state_bucket}",
      "arn:${var.partition}:s3:::${local.agent_state_bucket}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["CHAT_USAGE_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["CHAT_USAGE_DYNAMO_TABLE"]}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.chat_billing_params["MODEL_RATE_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.chat_billing_params["MODEL_RATE_TABLE"]}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.workflow_templates_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.workflow_templates_table}/*",
      "arn:${var.partition}:s3:::${local.workflow_templates_bucket}",
      "arn:${var.partition}:s3:::${local.workflow_templates_bucket}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.amplify_js_params["REQUEST_STATE_DYNAMO_TABLE"]}",
      "arn:${var.partition}:s3:::${var.lambda_params["S3_RAG_INPUT_BUCKET_NAME"]}/*",
      "arn:${var.partition}:s3:::${var.lambda_params["S3_IMAGE_INPUT_BUCKET_NAME"]}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["FILES_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["FILES_DYNAMO_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["USER_TAGS_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["USER_TAGS_DYNAMO_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.scheduled_tasks_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.scheduled_tasks_table}/index/*",
      "arn:${var.partition}:s3:::${local.scheduled_tasks_logs_bucket}",
      "arn:${var.partition}:s3:::${local.scheduled_tasks_logs_bucket}/*",
      "arn:${var.partition}:s3:::${var.lambda_params["S3_CONSOLIDATION_BUCKET_NAME"]}",
      "arn:${var.partition}:s3:::${var.lambda_params["S3_CONSOLIDATION_BUCKET_NAME"]}/*",
      "arn:${var.partition}:s3:::${data.aws_ssm_parameter.notes_raw_files_bucket.value}",
      "arn:${var.partition}:s3:::${data.aws_ssm_parameter.notes_raw_files_bucket.value}/*",
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:DeleteObject"]
    resources = ["arn:${var.partition}:s3:::${local.raw_emails_bucket}/*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:${var.partition}:s3:::${local.raw_emails_bucket}"]
  }

  statement {
    effect  = "Allow"
    actions = ["dynamodb:Query", "dynamodb:Scan", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem"]
    resources = [
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["COGNITO_USERS_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["COGNITO_USERS_DYNAMODB_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${data.aws_ssm_parameter.ai_scheduler_storage_table.value}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${data.aws_ssm_parameter.ai_scheduler_storage_table.value}/index/*",
    ]
  }

  statement {
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      data.aws_ssm_parameter.llm_secrets_arn.value,
      "arn:${var.partition}:secretsmanager:us-east-1:*:secret:${data.aws_ssm_parameter.app_arn_name.value}*",
      "arn:${var.partition}:secretsmanager:${var.region}:*:secret:${data.aws_ssm_parameter.secrets_arn_name.value}*",
    ]
  }

  statement {
    effect  = "Allow"
    actions = ["sqs:ChangeMessageVisibility", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ReceiveMessage", "sqs:SendMessage"]
    resources = [
      aws_sqs_queue.agent.arn,
      local.notes_ingest_queue_arn,
    ]
  }

  statement {
    effect  = "Allow"
    actions = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
    resources = [
      "arn:${var.partition}:bedrock:*::foundation-model/*",
      "arn:${var.partition}:bedrock:*:${var.account_id}:inference-profile/*",
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = ["arn:${var.partition}:ssm:${var.region}:${var.account_id}:parameter${var.ssm_base_path}-*"]
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

data "aws_iam_policy_document" "email_processing" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:DeleteObject"]
    resources = ["arn:${var.partition}:s3:::${local.raw_emails_bucket}/*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:${var.partition}:s3:::${local.raw_emails_bucket}"]
  }
}

resource "aws_iam_policy" "email_processing" {
  name   = local.email_policy_name
  policy = data.aws_iam_policy_document.email_processing.json
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
resource "aws_iam_role_policy_attachment" "email_processing" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.email_processing.arn
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
  package_path     = module.package.package_path
  source_code_hash = module.package.source_code_hash
  runtime          = "python3.11"
  timeout          = each.value.timeout
  memory_size      = each.value.memory_size
  layer_arns       = []
  environment      = local.environment
  role_arn         = aws_iam_role.lambda.arn
  tracing_mode     = "Active"
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

# ---- SQS event-source mapping ----
resource "aws_lambda_event_source_mapping" "agent_event_processor" {
  event_source_arn = aws_sqs_queue.agent.arn
  function_name    = module.fn["agentEventProcessor"].function_arn
  batch_size       = 1
}

# ---- Scheduled task ----
resource "aws_cloudwatch_event_rule" "scheduled_tasks" {
  name                = "${local.service_name}-${var.stage}-scheduled-tasks"
  schedule_expression = "rate(3 minutes)"
}
resource "aws_cloudwatch_event_target" "scheduled_tasks" {
  rule = aws_cloudwatch_event_rule.scheduled_tasks.name
  arn  = module.fn["scheduledTasksProcessor"].function_arn
}
resource "aws_lambda_permission" "scheduled_tasks" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = module.fn["scheduledTasksProcessor"].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scheduled_tasks.arn
}
