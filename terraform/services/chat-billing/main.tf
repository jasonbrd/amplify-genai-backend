locals {
  service_name = "${var.name_prefix}-chat-billing"
  src_dir      = "${path.module}/../../../chat-billing"
  build_dir    = "${path.root}/build/chat-billing"

  model_rate_table         = "${local.service_name}-${var.stage}-model-rates"
  additional_charges_table = "${local.service_name}-${var.stage}-additional-charges"
  policy_name              = "${local.service_name}-${var.stage}-iam-policy"

  # SES credentials secret (hardcoded ARN in the original serverless.yml).
  ses_secret_arn = "arn:${var.partition}:secretsmanager:us-east-1:*:secret:aws/ses/credentials-i82Vzw"

  published_params = {
    ADDITIONAL_CHARGES_TABLE = local.additional_charges_table
    MODEL_RATE_TABLE         = local.model_rate_table
  }

  functions = {
    get_user_available_models = { handler = "service/core.get_user_available_models", timeout = 30, memory_size = 1024, path = "available_models", method = "GET", cors = true }
    update_supported_models   = { handler = "service/core.update_supported_models", timeout = 30, memory_size = 1024, path = "supported_models/update", method = "POST", cors = true }
    get_supported_models      = { handler = "service/core.get_supported_models_as_admin", timeout = 30, memory_size = 1024, path = "supported_models/get", method = "GET", cors = true }
    get_default_models        = { handler = "service/core.get_default_models", timeout = 30, memory_size = 1024, path = "default_models", method = "GET", cors = true }
    tools_op                  = { handler = "tools_ops.api_tools_handler", timeout = 30, memory_size = 1024, path = "models/register_ops", method = "POST", cors = true }
  }

  environment = merge(var.shared_env, {
    SERVICE_NAME = local.service_name

    ADDITIONAL_CHARGES_TABLE = local.additional_charges_table
    MODEL_RATE_TABLE         = local.model_rate_table

    ACCOUNTS_DYNAMO_TABLE          = var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]
    AMPLIFY_ADMIN_DYNAMODB_TABLE   = var.admin_params["AMPLIFY_ADMIN_DYNAMODB_TABLE"]
    API_KEYS_DYNAMODB_TABLE        = var.object_access_params["API_KEYS_DYNAMODB_TABLE"]
    COGNITO_USERS_DYNAMODB_TABLE   = var.object_access_params["COGNITO_USERS_DYNAMODB_TABLE"]
    COST_CALCULATIONS_DYNAMO_TABLE = var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]
    CRITICAL_ERRORS_SQS_QUEUE_NAME = var.admin_params["CRITICAL_ERRORS_SQS_QUEUE_NAME"]
    ENV_VARS_TRACKING_TABLE        = var.lambda_params["ENV_VARS_TRACKING_TABLE"]
    OPS_DYNAMODB_TABLE             = var.lambda_ops_params["OPS_DYNAMODB_TABLE"]
  })
}

# ---- Packaging + deps layer ----
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
      "secretsmanager:GetSecretValue",
      "dynamodb:Query", "dynamodb:Scan", "dynamodb:GetItem", "dynamodb:PutItem",
      "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:CreateTable", "dynamodb:BatchWriteItem",
    ]
    resources = [
      local.ses_secret_arn,
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.model_rate_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.model_rate_table}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.additional_charges_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.additional_charges_table}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["API_KEYS_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["API_KEYS_DYNAMODB_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.admin_params["AMPLIFY_ADMIN_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.admin_params["AMPLIFY_ADMIN_DYNAMODB_TABLE"]}*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_ops_params["OPS_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_ops_params["OPS_DYNAMODB_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["COGNITO_USERS_DYNAMODB_TABLE"]}",
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

# ---- DynamoDB (import; never recreate) ----
resource "aws_dynamodb_table" "model_rate" {
  name         = local.model_rate_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ModelID"
  attribute {
    name = "ModelID"
    type = "S"
  }
  point_in_time_recovery { enabled = true }
  server_side_encryption { enabled = true }
}

resource "aws_dynamodb_table" "additional_charges" {
  name         = local.additional_charges_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  attribute {
    name = "id"
    type = "S"
  }
  point_in_time_recovery { enabled = true }
  server_side_encryption { enabled = true }
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
