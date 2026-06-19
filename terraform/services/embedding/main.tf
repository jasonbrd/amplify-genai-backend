locals {
  service_name = "${var.name_prefix}-embedding"
  src_dir      = "${path.module}/../../../embedding"
  build_dir    = "${path.root}/build/embedding"

  embedding_progress_table = "${local.service_name}-${var.stage}-embedding-progress"
  policy_name              = "${local.service_name}-${var.stage}-iam-policy"

  rag_db_name     = "RagVectorDb_${var.stage}"
  rag_db_username = "ragadmin_${var.stage}"
  rag_db_secret   = "${var.stage}/${local.service_name}/rag/postgres/db-creds"
  rag_db_cluster  = "${var.stage}-${local.service_name}-rag-cluster"
  rag_db_port     = tonumber(data.aws_ssm_parameter.rag_postgres_db_port.value)

  subnet_ids = [
    data.aws_ssm_parameter.private_subnet_one.value,
    data.aws_ssm_parameter.private_subnet_two.value,
  ]

  vpc_config = {
    subnet_ids         = local.subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  extended_timeout_fns = toset(["get_dual_embeddings"])

  # kind: http | sqs | none
  functions = {
    create_table                = { handler = "create_table.create_table", timeout = 6, memory_size = 1024, kind = "none", path = "", method = "", cors = false, vpc = true, reserved = -1 }
    process_chunk_for_embedding = { handler = "embedding.lambda_handler", timeout = 120, memory_size = 1024, kind = "sqs", path = "", method = "", cors = false, vpc = true, reserved = 200 }
    get_dual_embeddings         = { handler = "embedding-dual-retrieval.process_input_with_dual_retrieval", timeout = 300, memory_size = 1024, kind = "http", path = "embedding-dual-retrieval", method = "POST", cors = true, vpc = true, reserved = -1 }
    terminate_embedding         = { handler = "embedding.terminate_embedding", timeout = 15, memory_size = 1024, kind = "http", path = "embedding/terminate", method = "POST", cors = true, vpc = false, reserved = -1 }
    get_embedding_status        = { handler = "embedding.get_embedding_status", timeout = 30, memory_size = 1024, kind = "http", path = "embedding/status", method = "POST", cors = true, vpc = false, reserved = -1 }
    check_embedding_completion  = { handler = "embedding-dual-retrieval.queue_missing_embeddings", timeout = 15, memory_size = 1024, kind = "http", path = "embedding/check-completion", method = "POST", cors = true, vpc = false, reserved = -1 }
    get_sqs_messages            = { handler = "embedding-sqs.get_in_flight_messages", timeout = 15, memory_size = 1024, kind = "http", path = "embedding/sqs/get", method = "GET", cors = true, vpc = false, reserved = -1 }
    process_dlq_chunks          = { handler = "embedding-dlq-handler.lambda_handler", timeout = 60, memory_size = 1024, kind = "sqs", path = "", method = "", cors = false, vpc = false, reserved = -1 }
    delete_embeddings           = { handler = "embedding-delete.delete_embeddings", timeout = 300, memory_size = 1024, kind = "http", path = "embedding-delete", method = "POST", cors = true, vpc = true, reserved = -1 }
    bedrock_kb_download         = { handler = "bedrock-kb-download.bedrock_kb_download", timeout = 30, memory_size = 1024, kind = "http", path = "bedrock-kb/download", method = "POST", cors = true, vpc = false, reserved = -1 }
    tools_op                    = { handler = "tools_ops.api_tools_handler", timeout = 30, memory_size = 1024, kind = "http", path = "embedding/register_ops", method = "POST", cors = true, vpc = false, reserved = -1 }
  }

  http_functions = { for k, f in local.functions : k => f if f.kind == "http" }

  base_environment = merge(var.shared_env, {
    SERVICE_NAME = local.service_name
    REGION       = var.region

    API_VERSION                    = data.aws_ssm_parameter.api_version.value
    APP_ARN_NAME                   = data.aws_ssm_parameter.app_arn_name.value
    COGNITO_USER_POOL_ID           = data.aws_ssm_parameter.cognito_user_pool_id.value
    LLM_ENDPOINTS_SECRETS_NAME_ARN = data.aws_ssm_parameter.llm_secrets_arn.value
    MAX_ACU                        = data.aws_ssm_parameter.max_acu.value
    MIN_ACU                        = data.aws_ssm_parameter.min_acu.value
    PRIVATE_SUBNET_ONE             = data.aws_ssm_parameter.private_subnet_one.value
    PRIVATE_SUBNET_TWO             = data.aws_ssm_parameter.private_subnet_two.value
    SECRETS_ARN_NAME               = data.aws_ssm_parameter.secrets_arn_name.value
    VPC_CIDR                       = data.aws_ssm_parameter.vpc_cidr.value
    VPC_ID                         = data.aws_ssm_parameter.vpc_id.value
    EMBEDDING_DIM                  = data.aws_ssm_parameter.embedding_dim.value

    # RAG Postgres
    RAG_POSTGRES_DB_NAME           = local.rag_db_name
    RAG_POSTGRES_DB_USERNAME       = local.rag_db_username
    RAG_POSTGRES_DB_SECRET         = local.rag_db_secret
    RAG_POSTGRES_DB_PORT           = tostring(local.rag_db_port)
    RAG_POSTGRES_DB_WRITE_ENDPOINT = aws_rds_cluster.rag.endpoint
    RAG_POSTGRES_DB_READ_ENDPOINT  = aws_rds_cluster.rag.reader_endpoint
    RAG_POSTGRES_DB_CLUSTER        = local.rag_db_cluster

    # Local
    EMBEDDING_IAM_POLICY_NAME = local.policy_name
    EMBEDDING_PROGRESS_TABLE  = local.embedding_progress_table

    # Cross-service (SSM)
    ACCOUNTS_DYNAMO_TABLE           = var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]
    ADDITIONAL_CHARGES_TABLE        = var.chat_billing_params["ADDITIONAL_CHARGES_TABLE"]
    AMPLIFY_ADMIN_DYNAMODB_TABLE    = var.admin_params["AMPLIFY_ADMIN_DYNAMODB_TABLE"]
    API_KEYS_DYNAMODB_TABLE         = var.object_access_params["API_KEYS_DYNAMODB_TABLE"]
    ASSISTANT_GROUPS_DYNAMO_TABLE   = var.object_access_params["ASSISTANT_GROUPS_DYNAMO_TABLE"]
    ASSISTANT_LOOKUP_DYNAMODB_TABLE = var.assistants_params["ASSISTANT_LOOKUP_DYNAMODB_TABLE"]
    ASSISTANTS_DYNAMODB_TABLE       = var.assistants_params["ASSISTANTS_DYNAMODB_TABLE"]
    CHAT_USAGE_DYNAMO_TABLE         = var.lambda_params["CHAT_USAGE_DYNAMO_TABLE"]
    COGNITO_USERS_DYNAMODB_TABLE    = var.object_access_params["COGNITO_USERS_DYNAMODB_TABLE"]
    COST_CALCULATIONS_DYNAMO_TABLE  = var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]
    CRITICAL_ERRORS_SQS_QUEUE_NAME  = var.admin_params["CRITICAL_ERRORS_SQS_QUEUE_NAME"]
    ENV_VARS_TRACKING_TABLE         = var.lambda_params["ENV_VARS_TRACKING_TABLE"]
    HASH_FILES_DYNAMO_TABLE         = var.lambda_params["HASH_FILES_DYNAMO_TABLE"]
    MODEL_RATE_TABLE                = var.chat_billing_params["MODEL_RATE_TABLE"]
    OBJECT_ACCESS_DYNAMODB_TABLE    = var.object_access_params["OBJECT_ACCESS_DYNAMODB_TABLE"]
    OPS_DYNAMODB_TABLE              = var.lambda_ops_params["OPS_DYNAMODB_TABLE"]
    S3_FILE_TEXT_BUCKET_NAME        = var.lambda_params["S3_FILE_TEXT_BUCKET_NAME"]
    S3_IMAGE_INPUT_BUCKET_NAME      = var.lambda_params["S3_IMAGE_INPUT_BUCKET_NAME"]
    S3_RAG_CHUNKS_BUCKET_NAME       = var.lambda_params["S3_RAG_CHUNKS_BUCKET_NAME"]
  })

  # Per-function env additions (queue URLs from amplify-lambda).
  extra_env = {
    process_chunk_for_embedding = { EMBEDDING_CHUNKS_INDEX_QUEUE = var.embedding_chunks_queue_url }
    get_dual_embeddings         = { RAG_CHUNK_DOCUMENT_QUEUE_URL = var.rag_chunk_document_queue_url }
    get_embedding_status        = { EMBEDDING_CHUNKS_INDEX_QUEUE = var.embedding_chunks_queue_url }
    check_embedding_completion  = { RAG_CHUNK_DOCUMENT_QUEUE_URL = var.rag_chunk_document_queue_url }
    get_sqs_messages            = { EMBEDDING_CHUNKS_INDEX_QUEUE = var.embedding_chunks_queue_url }
  }
}

# ---- Shared SSM ----
data "aws_ssm_parameter" "api_version" { name = "${var.ssm_shared_path}/API_VERSION" }
data "aws_ssm_parameter" "app_arn_name" { name = "${var.ssm_shared_path}/APP_ARN_NAME" }
data "aws_ssm_parameter" "cognito_user_pool_id" { name = "${var.ssm_shared_path}/COGNITO_USER_POOL_ID" }
data "aws_ssm_parameter" "llm_secrets_arn" { name = "${var.ssm_shared_path}/LLM_ENDPOINTS_SECRETS_NAME_ARN" }
data "aws_ssm_parameter" "max_acu" { name = "${var.ssm_shared_path}/MAX_ACU" }
data "aws_ssm_parameter" "min_acu" { name = "${var.ssm_shared_path}/MIN_ACU" }
data "aws_ssm_parameter" "private_subnet_one" { name = "${var.ssm_shared_path}/PRIVATE_SUBNET_ONE" }
data "aws_ssm_parameter" "private_subnet_two" { name = "${var.ssm_shared_path}/PRIVATE_SUBNET_TWO" }
data "aws_ssm_parameter" "rag_postgres_db_port" { name = "${var.ssm_shared_path}/RAG_POSTGRES_DB_PORT" }
data "aws_ssm_parameter" "secrets_arn_name" { name = "${var.ssm_shared_path}/SECRETS_ARN_NAME" }
data "aws_ssm_parameter" "vpc_cidr" { name = "${var.ssm_shared_path}/VPC_CIDR" }
data "aws_ssm_parameter" "vpc_id" { name = "${var.ssm_shared_path}/VPC_ID" }
data "aws_ssm_parameter" "embedding_dim" { name = "${var.ssm_shared_path}/EMBEDDING_DIM" }

# ---- Packaging + deps layer (layer:true) ----
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

# ---- Networking ----
resource "aws_db_subnet_group" "rag" {
  name        = "${local.service_name}-${var.stage}-rag"
  description = "Subnet group for RDS Aurora Serverless PostgreSQL Vector Database"
  subnet_ids  = local.subnet_ids
}

resource "aws_security_group" "rag_db" {
  name        = "${local.service_name}-${var.stage}-rag-db"
  description = "Security group for RDS Aurora Serverless"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value

  ingress {
    from_port   = local.rag_db_port
    to_port     = local.rag_db_port
    protocol    = "tcp"
    cidr_blocks = [data.aws_ssm_parameter.vpc_cidr.value]
  }
  ingress {
    from_port   = local.rag_db_port
    to_port     = local.rag_db_port
    protocol    = "tcp"
    cidr_blocks = ["10.2.224.0/20"]
  }
}

resource "aws_security_group" "lambda" {
  name        = "${local.service_name}-${var.stage}-lambda"
  description = "Security group for Lambda Functions"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---- DB encryption key + credentials secret ----
resource "aws_kms_key" "rag_db" {
  description         = "KMS key for encrypting the RAG Postgres DB cluster"
  enable_key_rotation = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "Allow administration of the key"
      Effect    = "Allow"
      Principal = { AWS = "arn:${var.partition}:iam::${var.account_id}:root" }
      Action    = ["kms:*"]
      Resource  = "*"
    }]
  })
}

resource "random_password" "rag_db" {
  length           = 16
  override_special = "!#$%&*()-_=+[]{}<>:?"
  # ExcludeCharacters in the original: "@/\
}

resource "aws_secretsmanager_secret" "rag_db" {
  name        = local.rag_db_secret
  description = "Credentials for Aurora Serverless PostgreSQL Database"
}

resource "aws_secretsmanager_secret_version" "rag_db" {
  secret_id     = aws_secretsmanager_secret.rag_db.id
  secret_string = random_password.rag_db.result
}

# ---- Aurora PostgreSQL Serverless v2 ----
resource "aws_rds_cluster" "rag" {
  cluster_identifier              = local.rag_db_cluster
  engine                          = "aurora-postgresql"
  engine_version                  = "15.12"
  database_name                   = local.rag_db_name
  master_username                 = local.rag_db_username
  master_password                 = random_password.rag_db.result
  port                            = local.rag_db_port
  db_subnet_group_name            = aws_db_subnet_group.rag.name
  vpc_security_group_ids          = [aws_security_group.rag_db.id]
  backup_retention_period         = 7
  storage_encrypted               = true
  kms_key_id                      = aws_kms_key.rag_db.arn
  enable_http_endpoint            = true
  enabled_cloudwatch_logs_exports = ["postgresql"]
  deletion_protection             = true

  serverlessv2_scaling_configuration {
    min_capacity = tonumber(data.aws_ssm_parameter.min_acu.value)
    max_capacity = tonumber(data.aws_ssm_parameter.max_acu.value)
  }

  # DeletionPolicy: Snapshot in the original.
  final_snapshot_identifier = "${local.rag_db_cluster}-final"
}

resource "aws_rds_cluster_instance" "rag_1" {
  identifier         = "${local.rag_db_cluster}-1"
  cluster_identifier = aws_rds_cluster.rag.id
  engine             = "aurora-postgresql"
  instance_class     = "db.serverless"
}

# Second instance only in prod (Condition: IsProd).
resource "aws_rds_cluster_instance" "rag_2" {
  count              = var.stage == "prod" ? 1 : 0
  identifier         = "${local.rag_db_cluster}-2"
  cluster_identifier = aws_rds_cluster.rag.id
  engine             = "aurora-postgresql"
  instance_class     = "db.serverless"
}

# ---- DynamoDB ----
resource "aws_dynamodb_table" "embedding_progress" {
  name         = local.embedding_progress_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "object_id"
  attribute {
    name = "object_id"
    type = "S"
  }
  point_in_time_recovery { enabled = true }
  server_side_encryption { enabled = true }
}

# ---- IAM ----
data "aws_iam_policy_document" "service" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "s3:GetObject", "s3:HeadObject", "s3:ListBucket",
      "dynamodb:Query", "dynamodb:Scan", "dynamodb:GetItem", "dynamodb:PutItem",
      "dynamodb:UpdateItem", "dynamodb:DeleteItem",
      "sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes",
      "bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream",
    ]
    resources = [
      aws_rds_cluster.rag.arn,
      aws_secretsmanager_secret.rag_db.arn,
      data.aws_ssm_parameter.llm_secrets_arn.value,
      "arn:${var.partition}:s3:::${var.lambda_params["S3_RAG_CHUNKS_BUCKET_NAME"]}",
      "arn:${var.partition}:s3:::${var.lambda_params["S3_RAG_CHUNKS_BUCKET_NAME"]}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["OBJECT_ACCESS_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["OBJECT_ACCESS_DYNAMODB_TABLE"]}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["API_KEYS_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["API_KEYS_DYNAMODB_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["HASH_FILES_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["HASH_FILES_DYNAMO_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["CHAT_USAGE_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["CHAT_USAGE_DYNAMO_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["ASSISTANT_GROUPS_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["ASSISTANT_GROUPS_DYNAMO_TABLE"]}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.chat_billing_params["MODEL_RATE_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.chat_billing_params["MODEL_RATE_TABLE"]}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.admin_params["AMPLIFY_ADMIN_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.admin_params["AMPLIFY_ADMIN_DYNAMODB_TABLE"]}*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.assistants_params["ASSISTANT_LOOKUP_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.assistants_params["ASSISTANT_LOOKUP_DYNAMODB_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.assistants_params["ASSISTANTS_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.assistants_params["ASSISTANTS_DYNAMODB_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.embedding_progress_table}",
      var.embedding_chunks_queue_arn,
      var.embedding_chunks_dlq_arn,
      "arn:${var.partition}:bedrock:*:*:foundation-model/*",
      "arn:${var.partition}:bedrock:*:*:inference-profile/*",
      "arn:${var.partition}:secretsmanager:us-east-1:*:secret:${data.aws_ssm_parameter.app_arn_name.value}*",
      "arn:${var.partition}:secretsmanager:${var.region}:*:secret:${data.aws_ssm_parameter.secrets_arn_name.value}*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_ops_params["OPS_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_ops_params["OPS_DYNAMODB_TABLE"]}/index/*",
      "arn:${var.partition}:s3:::${var.lambda_params["S3_IMAGE_INPUT_BUCKET_NAME"]}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["COGNITO_USERS_DYNAMODB_TABLE"]}",
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [var.rag_chunk_document_queue_arn]
  }

  statement {
    effect  = "Allow"
    actions = ["ssm:GetParameter", "ssm:PutParameter", "ssm:DeleteParameter", "ssm:DescribeParameters"]
    resources = [
      "arn:${var.partition}:ssm:${var.region}:${var.account_id}:parameter/rag-ds/*",
      "arn:${var.partition}:ssm:${var.region}:${var.account_id}:parameter/rag-ds/${var.stage}/*",
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
    actions   = ["bedrock:Retrieve", "bedrock:RetrieveAndGenerate", "bedrock:ListDataSources", "bedrock:GetDataSource"]
    resources = ["arn:${var.partition}:bedrock:${var.region}:${var.account_id}:knowledge-base/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["arn:${var.partition}:s3:::*/*"]
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

resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:${var.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "service" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.service.arn
}

# ---- SSM publish ----
locals {
  published_params = {
    EMBEDDING_PROGRESS_TABLE = local.embedding_progress_table
  }
}

module "ssm_publish" {
  source     = "../../modules/ssm-publish"
  base_path  = "${var.ssm_shared_path}/${local.service_name}"
  parameters = local.published_params
}

# ---- Functions ----
module "fn" {
  source   = "../../modules/python-lambda"
  for_each = local.functions

  function_name                  = "${local.service_name}-${var.stage}-${each.key}"
  handler                        = each.value.handler
  package_path                   = data.archive_file.package.output_path
  source_code_hash               = data.archive_file.package.output_base64sha256
  runtime                        = "python3.11"
  timeout                        = each.value.timeout
  memory_size                    = each.value.memory_size
  layer_arns                     = [module.deps_layer.layer_arn]
  environment                    = merge(local.base_environment, lookup(local.extra_env, each.key, {}))
  role_arn                       = aws_iam_role.lambda.arn
  reserved_concurrent_executions = each.value.reserved
  vpc_config                     = each.value.vpc ? local.vpc_config : null
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
      timeout_ms    = contains(local.extended_timeout_fns, k) ? var.api_gateway_max_timeout_ms : null
    }
  ]
}

# ---- SQS event-source mappings (queues owned by amplify-lambda) ----
resource "aws_lambda_event_source_mapping" "process_chunk_for_embedding" {
  event_source_arn = var.embedding_chunks_queue_arn
  function_name    = module.fn["process_chunk_for_embedding"].function_arn
  batch_size       = 1
}

resource "aws_lambda_event_source_mapping" "process_dlq_chunks" {
  event_source_arn = var.embedding_chunks_dlq_arn
  function_name    = module.fn["process_dlq_chunks"].function_arn
  batch_size       = 10
}
