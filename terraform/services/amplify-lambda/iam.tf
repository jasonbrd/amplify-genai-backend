locals {
  ddb = "arn:${var.partition}:dynamodb:${var.region}"
  s3a = "arn:${var.partition}:s3:::"
  sqs = "arn:${var.partition}:sqs:${var.region}"
}

# ---- SSM policy ----
data "aws_iam_policy_document" "ssm" {
  statement {
    effect  = "Allow"
    actions = ["ssm:GetParameter", "ssm:PutParameter", "ssm:DeleteParameter", "ssm:DescribeParameters", "ssm:GetParametersByPath"]
    resources = [
      "arn:${var.partition}:ssm:${var.region}:${var.account_id}:parameter/rag-ds/*",
      "arn:${var.partition}:ssm:${var.region}:${var.account_id}:parameter/rag-ds/${var.stage}/*",
      "arn:${var.partition}:ssm:${var.region}:${var.account_id}:parameter/tools/web_search/*",
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
    resources = ["arn:${var.partition}:ssm:${var.region}:${var.account_id}:parameter/amplify/${var.stage}/${local.service_name}/*"]
  }
}

resource "aws_iam_policy" "ssm" {
  name   = "${local.lambda_iam_policy_name}-ssm"
  policy = data.aws_iam_policy_document.ssm.json
}

# ---- S3 policy ----
data "aws_iam_policy_document" "s3" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject", "s3:PutObject", "s3:PutObjectHold", "s3:DeleteObject", "s3:ListBucket",
      "s3:GetObjectAttributes", "s3:HeadObject", "s3:CreateBucket", "s3:GetBucketNotification", "s3:PutBucketNotification",
    ]
    resources = [
      "${local.s3a}${local.conversations_bucket}", "${local.s3a}${local.conversations_bucket}/*",
      "${local.s3a}${local.share_bucket}", "${local.s3a}${local.share_bucket}/*",
      "${local.s3a}${local.conversion_input_bucket}", "${local.s3a}${local.conversion_input_bucket}/*",
      "${local.s3a}${local.conversion_output_bucket}", "${local.s3a}${local.conversion_output_bucket}/*",
      "${local.s3a}${local.rag_input_bucket}/*",
      "${local.s3a}${local.image_input_bucket}/*",
      "${local.s3a}${local.rag_chunks_bucket}/*",
      "${local.s3a}${local.file_text_bucket}/*",
      "${local.s3a}${local.access_logs_bucket}/*", "${local.s3a}${local.access_logs_bucket}",
      "${local.s3a}${local.consolidation_bucket}", "${local.s3a}${local.consolidation_bucket}/*",
    ]
  }
}

resource "aws_iam_policy" "s3" {
  name   = "${local.lambda_iam_policy_name}-s3"
  policy = data.aws_iam_policy_document.s3.json
}

# ---- DynamoDB policy ----
data "aws_iam_policy_document" "dynamodb" {
  statement {
    effect  = "Allow"
    actions = ["dynamodb:Query", "dynamodb:Scan", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:BatchGetItem"]
    resources = [
      "${local.ddb}:*:table/${local.shares_table}", "${local.ddb}:*:table/${local.shares_table}/index/*",
      "${local.ddb}:*:table/${var.object_access_params["API_KEYS_DYNAMODB_TABLE"]}", "${local.ddb}:*:table/${var.object_access_params["API_KEYS_DYNAMODB_TABLE"]}/index/*",
      "${local.ddb}:*:table/${local.accounts_table}", "${local.ddb}:*:table/${local.accounts_table}/index/*",
      "${local.ddb}:*:table/${local.files_table}", "${local.ddb}:*:table/${local.files_table}/index/*",
      "${local.ddb}:*:table/${local.user_tags_table}", "${local.ddb}:*:table/${local.user_tags_table}/index/*",
      "${local.ddb}:*:table/${local.hash_files_table}", "${local.ddb}:*:table/${local.hash_files_table}/index/*",
      "${local.ddb}:*:table/${var.object_access_params["ASSISTANT_GROUPS_DYNAMO_TABLE"]}",
      "${local.ddb}:*:table/${var.object_access_params["OBJECT_ACCESS_DYNAMODB_TABLE"]}", "${local.ddb}:*:table/${var.object_access_params["OBJECT_ACCESS_DYNAMODB_TABLE"]}/index/*",
      "${local.ddb}:*:table/${local.chat_usage_table}",
      "${local.ddb}:*:table/${var.embedding_params["EMBEDDING_PROGRESS_TABLE"]}",
      "${local.ddb}:*:table/${var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]}", "${local.ddb}:*:table/${var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]}/*",
      "${local.ddb}:*:table/${local.conversation_metadata_table}", "${local.ddb}:*:table/${local.conversation_metadata_table}/index/*",
      "${local.ddb}:*:table/${var.admin_params["AMPLIFY_ADMIN_DYNAMODB_TABLE"]}", "${local.ddb}:*:table/${var.admin_params["AMPLIFY_ADMIN_DYNAMODB_TABLE"]}*",
      "${local.ddb}:*:table/${local.db_connections_table}",
      "${local.ddb}:*:table/${var.lambda_ops_params["OPS_DYNAMODB_TABLE"]}", "${local.ddb}:*:table/${var.lambda_ops_params["OPS_DYNAMODB_TABLE"]}/index/*",
      "${local.ddb}:*:table/${var.object_access_params["COGNITO_USERS_DYNAMODB_TABLE"]}",
      "${local.ddb}:*:table/${local.user_storage_table}", "${local.ddb}:*:table/${local.user_storage_table}/index/*",
      "${local.ddb}:*:table/${var.data_disclosure_params["DATA_DISCLOSURE_VERSIONS_TABLE"]}", "${local.ddb}:*:table/${var.data_disclosure_params["DATA_DISCLOSURE_VERSIONS_TABLE"]}/index/*",
      "${local.ddb}:*:table/${local.env_vars_tracking_table}", "${local.ddb}:*:table/${local.env_vars_tracking_table}/index/*",
      "${local.ddb}:*:table/${var.chat_billing_params["ADDITIONAL_CHARGES_TABLE"]}",
      "${local.ddb}:*:table/${local.poll_status_table}", "${local.ddb}:*:table/${local.poll_status_table}/index/*",
    ]
  }
}

resource "aws_iam_policy" "dynamodb" {
  name   = "${local.lambda_iam_policy_name}-dynamodb"
  policy = data.aws_iam_policy_document.dynamodb.json
}

# ---- SQS policy ----
data "aws_iam_policy_document" "sqs" {
  statement {
    effect  = "Allow"
    actions = ["sqs:SendMessage", "sqs:DeleteMessage", "sqs:ReceiveMessage", "sqs:GetQueueAttributes", "sqs:ChangeMessageVisibility"]
    resources = [
      "${local.sqs}:*:${local.rag_document_index_queue}",
      "${local.sqs}:*:${local.rag_chunk_document_queue}",
      "${local.sqs}:*:${local.embedding_chunks_queue}",
      "${local.sqs}:*:${local.embedding_chunks_dlq}",
      "${local.sqs}:*:${local.rag_document_index_queue}-dlq",
      "${local.sqs}:*:${local.rag_chunk_document_queue}-dlq",
      "${local.sqs}:*:${var.admin_params["CRITICAL_ERRORS_SQS_QUEUE_NAME"]}",
    ]
  }
}

resource "aws_iam_policy" "sqs" {
  name   = "${local.lambda_iam_policy_name}-sqs"
  policy = data.aws_iam_policy_document.sqs.json
}

# ---- Secrets policy ----
data "aws_iam_policy_document" "secrets" {
  statement {
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      "arn:${var.partition}:secretsmanager:us-east-1:*:secret:${data.aws_ssm_parameter.app_arn_name.value}*",
      "arn:${var.partition}:secretsmanager:${var.region}:*:secret:${var.stage}-openai-endpoints*",
    ]
  }
}

resource "aws_iam_policy" "secrets" {
  name   = "${local.lambda_iam_policy_name}-secrets"
  policy = data.aws_iam_policy_document.secrets.json
}

# ---- RDS Data API policy ----
data "aws_iam_policy_document" "rds" {
  statement {
    effect    = "Allow"
    actions   = ["rds-data:ExecuteStatement", "rds-data:BatchExecuteStatement", "rds-data:BeginTransaction", "rds-data:CommitTransaction", "rds-data:RollbackTransaction"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "rds" {
  name   = "${local.lambda_iam_policy_name}-rds"
  policy = data.aws_iam_policy_document.rds.json
}

# ---- API Gateway policy (runtime integration timeout patching is now native,
# but the original granted these for the runtime_config_manager; kept minimal) ----
data "aws_iam_policy_document" "apigateway" {
  statement {
    effect  = "Allow"
    actions = ["apigateway:GET", "apigateway:PATCH"]
    resources = [
      "arn:${var.partition}:apigateway:${var.region}::/restapis/*/resources",
      "arn:${var.partition}:apigateway:${var.region}::/restapis/*/resources/*",
      "arn:${var.partition}:apigateway:${var.region}::/restapis/*/integrations/*",
    ]
  }
}

resource "aws_iam_policy" "apigateway" {
  name   = "${local.lambda_iam_policy_name}-apigateway"
  policy = data.aws_iam_policy_document.apigateway.json
}

# ---- Shared execution role ----
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

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = {
    ssm        = aws_iam_policy.ssm.arn
    s3         = aws_iam_policy.s3.arn
    dynamodb   = aws_iam_policy.dynamodb.arn
    sqs        = aws_iam_policy.sqs.arn
    secrets    = aws_iam_policy.secrets.arn
    rds        = aws_iam_policy.rds.arn
    apigateway = aws_iam_policy.apigateway.arn
  }
  role       = aws_iam_role.lambda.name
  policy_arn = each.value
}
