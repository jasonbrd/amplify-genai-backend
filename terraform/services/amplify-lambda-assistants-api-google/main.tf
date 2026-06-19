locals {
  service_name = "${var.name_prefix}-google"
  src_dir      = "${path.module}/../../../amplify-lambda-assistants-api-google"
  build_dir    = "${path.root}/build/amplify-lambda-assistants-api-google"

  policy_name = "${local.service_name}-${var.stage}-iam-policy"

  extended_timeout_fns = toset(["googleIntegrationsRouter"])

  functions = {
    googleListIntegrations      = { handler = "integrations/oauth.get_integrations", timeout = 30, memory_size = 1024, kind = "http", path = "google/integrations", method = "GET", cors = false }
    googleIntegrationsRouter    = { handler = "service/core.route_request", timeout = 300, memory_size = 1024, kind = "http", path = "google/integrations/{proxy+}", method = "POST", cors = false }
    googleAdminConfigOpsTrigger = { handler = "service/register_ops.integration_config_trigger", timeout = 300, memory_size = 1024, kind = "stream", path = "", method = "", cors = false }
  }

  http_functions = { for k, f in local.functions : k => f if f.kind == "http" }

  environment = merge(var.shared_env, {
    SERVICE_NAME               = local.service_name
    INTEGRATION_STAGE          = var.stage
    OAUTH_ENCRYPTION_PARAMETER = data.aws_ssm_parameter.oauth_encryption_parameter.value

    ACCOUNTS_DYNAMO_TABLE          = var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]
    ADDITIONAL_CHARGES_TABLE       = var.chat_billing_params["ADDITIONAL_CHARGES_TABLE"]
    AMPLIFY_ADMIN_DYNAMODB_TABLE   = var.admin_params["AMPLIFY_ADMIN_DYNAMODB_TABLE"]
    API_KEYS_DYNAMODB_TABLE        = var.object_access_params["API_KEYS_DYNAMODB_TABLE"]
    COGNITO_USERS_DYNAMODB_TABLE   = var.object_access_params["COGNITO_USERS_DYNAMODB_TABLE"]
    COST_CALCULATIONS_DYNAMO_TABLE = var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]
    CRITICAL_ERRORS_SQS_QUEUE_NAME = var.admin_params["CRITICAL_ERRORS_SQS_QUEUE_NAME"]
    ENV_VARS_TRACKING_TABLE        = var.lambda_params["ENV_VARS_TRACKING_TABLE"]
    OAUTH_USER_TABLE               = var.assistants_api_params["OAUTH_USER_TABLE"]
    OPS_DYNAMODB_TABLE             = var.lambda_ops_params["OPS_DYNAMODB_TABLE"]
  })
}

# ---- Shared + cross-service SSM ----
data "aws_ssm_parameter" "oauth_encryption_parameter" {
  name = "${var.ssm_shared_path}/OAUTH_ENCRYPTION_PARAMETER"
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
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.assistants_api_params["OAUTH_USER_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_ops_params["OPS_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_ops_params["OPS_DYNAMODB_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["COGNITO_USERS_DYNAMODB_TABLE"]}",
    ]
  }

  statement {
    effect  = "Allow"
    actions = ["ssm:GetParameter"]
    resources = [
      "arn:${var.partition}:ssm:${var.region}:${var.account_id}:parameter/oauth/*",
      "arn:${var.partition}:ssm:${var.region}:${var.account_id}:parameter${data.aws_ssm_parameter.oauth_encryption_parameter.value}*",
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["dynamodb:DescribeStream", "dynamodb:GetRecords", "dynamodb:GetShardIterator", "dynamodb:ListStreams"]
    resources = ["arn:${var.partition}:dynamodb:${var.region}:*:table/${var.admin_params["AMPLIFY_ADMIN_DYNAMODB_TABLE"]}/stream/*"]
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
      timeout_ms    = contains(local.extended_timeout_fns, k) ? var.api_gateway_max_timeout_ms : null
    }
  ]
}

# ---- DynamoDB stream trigger on the admin configs table ----
resource "aws_lambda_event_source_mapping" "admin_config_ops" {
  event_source_arn  = var.admin_table_stream_arn
  function_name     = module.fn["googleAdminConfigOpsTrigger"].function_arn
  starting_position = "TRIM_HORIZON"
  batch_size        = 1
  enabled           = true
}
