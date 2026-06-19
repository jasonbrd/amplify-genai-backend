locals {
  service_name = "${var.name_prefix}-artifacts"
  src_dir      = "${path.module}/../../../amplify-lambda-artifacts"
  build_dir    = "${path.root}/build/amplify-lambda-artifacts"

  artifacts_table  = "${local.service_name}-${var.stage}-user-artifacts"
  artifacts_bucket = "${local.service_name}-${var.stage}-bucket" # marked for future deletion
  policy_name      = "${local.service_name}-${var.stage}-iam-policy"

  published_params = {
    ARTIFACTS_DYNAMODB_TABLE = local.artifacts_table
  }

  functions = {
    get_all_artifacts = { handler = "service/core.get_artifacts_info", timeout = 6, memory_size = 1024, path = "artifacts/get_all", method = "GET", cors = true }
    get_artifact      = { handler = "service/core.get_artifact", timeout = 6, memory_size = 1024, path = "artifacts/get", method = "GET", cors = true }
    save_artifact     = { handler = "service/core.save_artifact", timeout = 6, memory_size = 1024, path = "artifacts/save", method = "POST", cors = true }
    delete_artifact   = { handler = "service/core.delete_artifact", timeout = 6, memory_size = 1024, path = "artifacts/delete", method = "DELETE", cors = true }
    share_artifacts   = { handler = "service/core.share_artifact", timeout = 900, memory_size = 1024, path = "artifacts/share", method = "POST", cors = true }
  }

  environment = merge(var.shared_env, {
    SERVICE_NAME = local.service_name

    ARTIFACTS_DYNAMODB_TABLE = local.artifacts_table
    S3_ARTIFACTS_BUCKET      = local.artifacts_bucket

    ACCOUNTS_DYNAMO_TABLE          = var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]
    ADDITIONAL_CHARGES_TABLE       = var.chat_billing_params["ADDITIONAL_CHARGES_TABLE"]
    API_KEYS_DYNAMODB_TABLE        = var.object_access_params["API_KEYS_DYNAMODB_TABLE"]
    COGNITO_USERS_DYNAMODB_TABLE   = var.object_access_params["COGNITO_USERS_DYNAMODB_TABLE"]
    COST_CALCULATIONS_DYNAMO_TABLE = var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]
    CRITICAL_ERRORS_SQS_QUEUE_NAME = var.admin_params["CRITICAL_ERRORS_SQS_QUEUE_NAME"]
    ENV_VARS_TRACKING_TABLE        = var.lambda_params["ENV_VARS_TRACKING_TABLE"]
    USER_STORAGE_TABLE             = var.lambda_params["USER_STORAGE_TABLE"]
  })
}

# ---- Cross-service resource names (from producer module outputs; replaces the
# SSM data-source reads). Wired in root main.tf from each producer's
# published_params output, so a fresh environment resolves these at plan time. ----

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

# ---- IAM ----
data "aws_iam_policy_document" "service" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:Query", "dynamodb:Scan", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
      "s3:GetObject", "s3:PutObject", "s3:ListBucket", "s3:DeleteObject",
    ]
    resources = [
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["API_KEYS_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["API_KEYS_DYNAMODB_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.artifacts_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["COGNITO_USERS_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]}/*",
      "arn:${var.partition}:s3:::${local.artifacts_bucket}/",
      "arn:${var.partition}:s3:::${local.artifacts_bucket}/*",
    ]
  }

  statement {
    effect  = "Allow"
    actions = ["dynamodb:GetItem", "dynamodb:DeleteItem"]
    resources = [
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["USER_STORAGE_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["USER_STORAGE_TABLE"]}/index/*",
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
resource "aws_dynamodb_table" "artifacts" {
  name         = local.artifacts_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  attribute {
    name = "user_id"
    type = "S"
  }
  point_in_time_recovery { enabled = true }
  server_side_encryption { enabled = true }
}

# ---- S3 (DeletionPolicy: Retain in CFN -> prevent_destroy here). Marked for
# future deletion in the original config; retained + imported for now.
resource "aws_s3_bucket" "artifacts" {
  bucket = local.artifacts_bucket

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_cors_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  cors_rule {
    allowed_origins = ["*"]
    allowed_methods = ["GET", "PUT", "DELETE"]
    allowed_headers = ["*"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
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
