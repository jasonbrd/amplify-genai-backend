locals {
  service_name = "${var.name_prefix}-api"
  src_dir      = "${path.module}/../../../amplify-lambda-api"
  build_dir    = "${path.root}/build/amplify-lambda-api"

  api_docs_bucket = "${local.service_name}-${var.stage}-documentation-bucket" # marked for future deletion
  policy_name     = "${local.service_name}-${var.stage}-iam-policy"

  # VPC config for the notebook-proxy functions.
  vpc_config = {
    subnet_ids = [
      data.aws_ssm_parameter.private_subnet_one.value,
      data.aws_ssm_parameter.private_subnet_two.value,
    ]
    security_group_ids = [aws_security_group.notebook_proxy.id]
  }

  functions = {
    get_doc_templates  = { handler = "service/core.get_api_document_templates", timeout = 6, memory_size = 1024, path = "apiKeys/api_documentation/get_templates", method = "GET", cors = true, vpc = false }
    get_api_keys       = { handler = "service/core.get_api_keys_for_user", timeout = 6, memory_size = 1024, path = "apiKeys/keys/get", method = "GET", cors = true, vpc = false }
    get_api_keys_ast   = { handler = "service/core.get_api_keys_for_assistant", timeout = 6, memory_size = 1024, path = "apiKeys/get_keys_ast", method = "GET", cors = true, vpc = false }
    rotate_api_key     = { handler = "service/core.rotate_api_key", timeout = 6, memory_size = 1024, path = "apiKeys/key/rotate", method = "POST", cors = true, vpc = false }
    create_api_keys    = { handler = "service/core.create_api_keys", timeout = 6, memory_size = 1024, path = "apiKeys/keys/create", method = "POST", cors = true, vpc = false }
    update_api_key     = { handler = "service/core.update_api_keys_for_user", timeout = 6, memory_size = 1024, path = "apiKeys/keys/update", method = "POST", cors = true, vpc = false }
    deactivate_key     = { handler = "service/core.deactivate_key", timeout = 6, memory_size = 1024, path = "apiKeys/key/deactivate", method = "POST", cors = true, vpc = false }
    get_system_ids     = { handler = "service/core.get_system_ids", timeout = 6, memory_size = 1024, path = "apiKeys/get_system_ids", method = "GET", cors = true, vpc = false }
    get_api_doc        = { handler = "service/core.get_documentation", timeout = 6, memory_size = 1024, path = "apiKeys/api_documentation/get", method = "GET", cors = true, vpc = false }
    upload_api_doc     = { handler = "service/core.get_api_doc_presigned_urls", timeout = 6, memory_size = 1024, path = "apiKeys/api_documentation/upload", method = "POST", cors = true, vpc = false }
    tools_op           = { handler = "tools_ops.api_tools_handler", timeout = 30, memory_size = 1024, path = "apiKeys/register_ops", method = "POST", cors = true, vpc = false }
    notebook_proxy     = { handler = "service/notebook_proxy.notebook_proxy", timeout = 900, memory_size = 1024, path = "notebook/proxy", method = "POST", cors = true, vpc = true }
    notebook_proxy_raw = { handler = "service/notebook_proxy.notebook_proxy_raw", timeout = 29, memory_size = 1024, path = "notebook/proxy/raw", method = "POST", cors = true, vpc = true }
    notebook_upload    = { handler = "service/notebook_proxy.notebook_upload", timeout = 29, memory_size = 1024, path = "notebook/upload", method = "POST", cors = true, vpc = true }
  }

  environment = merge(var.shared_env, {
    SERVICE_NAME = local.service_name

    S3_API_DOCUMENTATION_BUCKET = local.api_docs_bucket

    # Notebook proxy (optional shared SSM values)
    OPEN_NOTEBOOK_INTERNAL_URL = data.aws_ssm_parameter.open_notebook_url.value
    PRIVATE_SUBNET_ONE         = data.aws_ssm_parameter.private_subnet_one.value
    PRIVATE_SUBNET_TWO         = data.aws_ssm_parameter.private_subnet_two.value
    VPC_ID                     = data.aws_ssm_parameter.vpc_id.value

    ACCOUNTS_DYNAMO_TABLE          = var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]
    ADDITIONAL_CHARGES_TABLE       = var.chat_billing_params["ADDITIONAL_CHARGES_TABLE"]
    API_KEYS_DYNAMODB_TABLE        = var.object_access_params["API_KEYS_DYNAMODB_TABLE"]
    COGNITO_USERS_DYNAMODB_TABLE   = var.object_access_params["COGNITO_USERS_DYNAMODB_TABLE"]
    COST_CALCULATIONS_DYNAMO_TABLE = var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]
    CRITICAL_ERRORS_SQS_QUEUE_NAME = var.admin_params["CRITICAL_ERRORS_SQS_QUEUE_NAME"]
    ENV_VARS_TRACKING_TABLE        = var.lambda_params["ENV_VARS_TRACKING_TABLE"]
    OPS_DYNAMODB_TABLE             = var.lambda_ops_params["OPS_DYNAMODB_TABLE"]
    S3_CONSOLIDATION_BUCKET_NAME   = var.lambda_params["S3_CONSOLIDATION_BUCKET_NAME"]
    POLL_STATUS_TABLE              = var.lambda_params["POLL_STATUS_TABLE"]
  })
}

# ---- Shared + cross-service SSM ----
# Notebook-proxy networking values. In the original these had `, ''` defaults;
# they come from the external IaC. They must exist in SSM for this service.
data "aws_ssm_parameter" "open_notebook_url" {
  name = "${var.ssm_shared_path}/OPEN_NOTEBOOK_INTERNAL_URL"
}
data "aws_ssm_parameter" "private_subnet_one" {
  name = "${var.ssm_shared_path}/PRIVATE_SUBNET_ONE"
}
data "aws_ssm_parameter" "private_subnet_two" {
  name = "${var.ssm_shared_path}/PRIVATE_SUBNET_TWO"
}
data "aws_ssm_parameter" "vpc_id" {
  name = "${var.ssm_shared_path}/VPC_ID"
}

# ---- Packaging: source + vendored deps in one zip (no layer) ----
module "package" {
  source            = "../../modules/python-package"
  source_dir        = local.src_dir
  requirements_path = "${local.src_dir}/requirements.txt"
  build_dir         = local.build_dir
  runtime           = "python3.11"
  architecture      = "x86_64"
  dockerize         = true
}

# ---- Security group for the notebook-proxy VPC lambdas ----
resource "aws_security_group" "notebook_proxy" {
  name        = "${local.service_name}-${var.stage}-notebook-proxy-sg"
  description = "Notebook proxy Lambda - egress to Open Notebook VPC"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.service_name}-${var.stage}-notebook-proxy-sg"
  }
}

# ---- IAM ----
data "aws_iam_policy_document" "service" {
  statement {
    effect  = "Allow"
    actions = ["dynamodb:Query", "dynamodb:Scan", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"]
    resources = [
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["API_KEYS_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["API_KEYS_DYNAMODB_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_ops_params["OPS_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_ops_params["OPS_DYNAMODB_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["COGNITO_USERS_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["POLL_STATUS_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["POLL_STATUS_TABLE"]}/index/*",
    ]
  }

  statement {
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
    resources = [
      "arn:${var.partition}:s3:::${var.lambda_params["S3_CONSOLIDATION_BUCKET_NAME"]}",
      "arn:${var.partition}:s3:::${var.lambda_params["S3_CONSOLIDATION_BUCKET_NAME"]}/*",
      "arn:${var.partition}:s3:::${local.api_docs_bucket}",
      "arn:${var.partition}:s3:::${local.api_docs_bucket}/*",
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

# Required for VPC-attached lambdas to manage their ENIs (Serverless injected this
# automatically when a function had a vpc config).
resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:${var.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ---- S3 (marked for future deletion; retained + imported) ----
resource "aws_s3_bucket" "api_docs" {
  bucket = local.api_docs_bucket
}

resource "aws_s3_bucket_cors_configuration" "api_docs" {
  bucket = aws_s3_bucket.api_docs.id
  cors_rule {
    allowed_origins = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_headers = ["*"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "api_docs" {
  bucket = aws_s3_bucket.api_docs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
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
  vpc_config       = each.value.vpc ? local.vpc_config : null
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
    }
  ]
}
