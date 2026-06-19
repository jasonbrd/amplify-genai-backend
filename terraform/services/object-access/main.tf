locals {
  service_name = "${var.name_prefix}-object-access"
  src_dir      = "${path.module}/../../../object-access"
  build_dir    = "${path.root}/build/object-access"

  # Locally-owned resource names (match `${self:service}-${sls:stage}-*`).
  object_access_table      = "${local.service_name}-${var.stage}-object-access"
  cognito_users_table      = "${local.service_name}-${var.stage}-cognito-users"
  api_keys_table           = "${local.service_name}-${var.stage}-api-keys"
  amplify_groups_table     = "${local.service_name}-${var.stage}-amplify-groups"
  amplify_group_logs_table = "${local.service_name}-${var.stage}-amplify-group-logs"

  # Locally-defined env vars published to SSM for other services to consume.
  published_params = {
    API_KEYS_DYNAMODB_TABLE           = local.api_keys_table
    COGNITO_USERS_DYNAMODB_TABLE      = local.cognito_users_table
    OBJECT_ACCESS_DYNAMODB_TABLE      = local.object_access_table
    ASSISTANT_GROUPS_DYNAMO_TABLE     = local.amplify_groups_table
    AMPLIFY_GROUP_LOGS_DYNAMODB_TABLE = local.amplify_group_logs_table
  }

  # Functions whose API GW integration timeout the retired ApiGatewayTimeoutConfig
  # custom resource used to extend. Now driven by var.api_gateway_max_timeout_ms.
  extended_timeout_fns = toset([
    "cognito_users_get_emails",
    "update_object_perms",
    "can_access_objects",
    "simulate_access",
    "update_group_assistants",
  ])

  # Functions — mirrors serverless.yml. memory_size 1024 is the Serverless default
  # for functions that did not set memorySize.
  functions = {
    cognito_users_get_emails  = { handler = "cognito_users.get_emails", timeout = 15, memory_size = 1024, path = "utilities/emails", method = "GET", cors = false }
    get_cognito_amp_groups    = { handler = "cognito_users.get_user_groups", timeout = 12, memory_size = 1024, path = "utilities/get_user_groups", method = "GET", cors = false }
    update_object_perms       = { handler = "object_access.update_object_permissions", timeout = 300, memory_size = 1024, path = "utilities/update_object_permissions", method = "POST", cors = true }
    can_access_objects        = { handler = "object_access.can_access_objects", timeout = 15, memory_size = 1024, path = "utilities/can_access_objects", method = "POST", cors = true }
    simulate_access           = { handler = "object_access.simulate_access_to_objects", timeout = 15, memory_size = 1024, path = "utilities/simulate_access_to_objects", method = "POST", cors = true }
    validate_users            = { handler = "object_access.validate_users", timeout = 15, memory_size = 1024, path = "utilities/validate_users", method = "POST", cors = true }
    create_ast_admin_group    = { handler = "groups.create_group", timeout = 12, memory_size = 1024, path = "groups/create", method = "POST", cors = true }
    create_amplify_asts       = { handler = "groups.create_amplify_assistants", timeout = 12, memory_size = 1024, path = "groups/assistants/amplify", method = "POST", cors = true }
    replace_group_key         = { handler = "groups.replace_group_key", timeout = 12, memory_size = 1024, path = "groups/replace_key", method = "POST", cors = true }
    update_group_members      = { handler = "groups.update_members", timeout = 12, memory_size = 1024, path = "groups/update/members", method = "POST", cors = true }
    update_group_types        = { handler = "groups.update_group_types", timeout = 12, memory_size = 1024, path = "groups/update/types", method = "POST", cors = true }
    update_group_amp_groups   = { handler = "groups.update_amplify_groups", timeout = 12, memory_size = 1024, path = "groups/update/amplify_groups", method = "POST", cors = true }
    update_group_system_users = { handler = "groups.update_system_users", timeout = 12, memory_size = 1024, path = "groups/update/system_users", method = "POST", cors = true }
    update_member_permission  = { handler = "groups.update_members_permission", timeout = 12, memory_size = 1024, path = "groups/update/members/permissions", method = "POST", cors = true }
    list_groups               = { handler = "groups.list_groups", timeout = 30, memory_size = 1024, path = "groups/list", method = "GET", cors = true }
    list_all_groups           = { handler = "groups.list_all_groups_for_admins", timeout = 30, memory_size = 1024, path = "groups/list_all", method = "GET", cors = true }
    update_groups_by_admins   = { handler = "groups.update_ast_admin_groups", timeout = 12, memory_size = 1024, path = "groups/update", method = "POST", cors = true }
    update_group_assistants   = { handler = "groups.update_group_assistants", timeout = 30, memory_size = 1024, path = "groups/update/assistants", method = "POST", cors = true }
    delete_group              = { handler = "groups.delete_group", timeout = 12, memory_size = 1024, path = "groups/delete", method = "DELETE", cors = true }
    add_group_assistant_path  = { handler = "groups.add_path_to_assistant", timeout = 30, memory_size = 1024, path = "groups/assistant/add_path", method = "POST", cors = true }
    is_member_of_Ast_group    = { handler = "groups.verify_is_member_ast_group", timeout = 30, memory_size = 1024, path = "groups/verify_ast_group_member", method = "POST", cors = true }
    create_or_update_user     = { handler = "users.create_or_update_user", timeout = 60, memory_size = 1024, path = "user/create", method = "POST", cors = true }
  }

  environment = merge(var.shared_env, {
    SERVICE_NAME         = local.service_name
    COGNITO_USER_POOL_ID = data.aws_ssm_parameter.cognito_user_pool_id.value

    # Local
    AMPLIFY_GROUP_LOGS_DYNAMODB_TABLE = local.amplify_group_logs_table
    ASSISTANT_GROUPS_DYNAMO_TABLE     = local.amplify_groups_table
    API_KEYS_DYNAMODB_TABLE           = local.api_keys_table
    COGNITO_USERS_DYNAMODB_TABLE      = local.cognito_users_table
    OBJECT_ACCESS_DYNAMODB_TABLE      = local.object_access_table

    # Cross-service (from SSM)
    ACCOUNTS_DYNAMO_TABLE          = var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]
    ADDITIONAL_CHARGES_TABLE       = var.chat_billing_params["ADDITIONAL_CHARGES_TABLE"]
    AMPLIFY_ADMIN_DYNAMODB_TABLE   = var.admin_params["AMPLIFY_ADMIN_DYNAMODB_TABLE"]
    COST_CALCULATIONS_DYNAMO_TABLE = var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]
    CRITICAL_ERRORS_SQS_QUEUE_NAME = var.admin_params["CRITICAL_ERRORS_SQS_QUEUE_NAME"]
    ENV_VARS_TRACKING_TABLE        = var.lambda_params["ENV_VARS_TRACKING_TABLE"]
    FILES_DYNAMO_TABLE             = var.lambda_params["FILES_DYNAMO_TABLE"]
    HASH_FILES_DYNAMO_TABLE        = var.lambda_params["HASH_FILES_DYNAMO_TABLE"]
  })
}

# ----------------------------------------------------------------------------
# Shared + cross-service values from SSM.
# ----------------------------------------------------------------------------
data "aws_ssm_parameter" "cognito_user_pool_id" {
  name = "${var.ssm_shared_path}/COGNITO_USER_POOL_ID"
}

# ----------------------------------------------------------------------------
# Packaging + deps layer.
# ----------------------------------------------------------------------------
data "archive_file" "package" {
  type        = "zip"
  source_dir  = local.src_dir
  output_path = "${local.build_dir}/package.zip"

  excludes = [
    "serverless.yml", "requirements.txt", "node_modules", "venv",
    ".serverless", "package", "__pycache__", ".gitignore",
  ]
}

module "deps_layer" {
  source = "../../modules/python-deps-layer"

  layer_name        = "${local.service_name}-${var.stage}-python-requirements"
  requirements_path = "${local.src_dir}/requirements.txt"
  runtime           = "python3.11"
  architecture      = "x86_64"
  build_dir         = "${local.build_dir}/layer"
  dockerize         = true
}

# ----------------------------------------------------------------------------
# IAM: one managed policy (auto-named in Serverless — use name_prefix so import
# keeps the existing generated name without forcing a replace) + shared role.
# ----------------------------------------------------------------------------
data "aws_iam_policy_document" "service" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:Scan", "dynamodb:GetItem", "dynamodb:PutItem",
      "dynamodb:UpdateItem", "dynamodb:Query", "dynamodb:DeleteItem",
    ]
    resources = [
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.cognito_users_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.object_access_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.api_keys_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.api_keys_table}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.amplify_groups_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.amplify_group_logs_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["HASH_FILES_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.admin_params["AMPLIFY_ADMIN_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["FILES_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["FILES_DYNAMO_TABLE"]}/index/*",
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["cognito-idp:ListUsers"]
    resources = ["arn:${var.partition}:cognito-idp:${var.region}:*:userpool/${data.aws_ssm_parameter.cognito_user_pool_id.value}"]
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
  name_prefix = "${local.service_name}-${var.stage}-"
  policy      = data.aws_iam_policy_document.service.json
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
  # Matches the Serverless-generated role name (region embedded).
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

# ----------------------------------------------------------------------------
# DynamoDB tables (IMPORT these; never recreate).
# ----------------------------------------------------------------------------
resource "aws_dynamodb_table" "object_access" {
  name         = local.object_access_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "object_id"
  range_key    = "principal_id"

  attribute {
    name = "object_id"
    type = "S"
  }
  attribute {
    name = "principal_id"
    type = "S"
  }
  global_secondary_index {
    name            = "PrincipalIdIndex"
    hash_key        = "principal_id"
    projection_type = "ALL"
  }
  point_in_time_recovery { enabled = true }
  server_side_encryption { enabled = true }
}

resource "aws_dynamodb_table" "cognito_users" {
  name         = local.cognito_users_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }
  point_in_time_recovery { enabled = true }
  server_side_encryption { enabled = true }
}

resource "aws_dynamodb_table" "api_keys" {
  name         = local.api_keys_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "api_owner_id"

  attribute {
    name = "api_owner_id"
    type = "S"
  }
  attribute {
    name = "apiKey"
    type = "S"
  }
  global_secondary_index {
    name            = "ApiKeyIndex"
    hash_key        = "apiKey"
    projection_type = "ALL"
  }
  point_in_time_recovery { enabled = true }
  server_side_encryption { enabled = true }
}

resource "aws_dynamodb_table" "amplify_groups" {
  name         = local.amplify_groups_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "group_id"

  attribute {
    name = "group_id"
    type = "S"
  }
  point_in_time_recovery { enabled = true }
  server_side_encryption { enabled = true }
}

resource "aws_dynamodb_table" "amplify_group_logs" {
  name         = local.amplify_group_logs_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "log_id"

  attribute {
    name = "log_id"
    type = "S"
  }
  point_in_time_recovery { enabled = true }
  server_side_encryption { enabled = true }
}

# ----------------------------------------------------------------------------
# Publish locally-owned names to SSM (replaces parameter_store_populator).
# ----------------------------------------------------------------------------
module "ssm_publish" {
  source     = "../../modules/ssm-publish"
  base_path  = "${var.ssm_shared_path}/${local.service_name}"
  parameters = local.published_params
}

# ----------------------------------------------------------------------------
# Functions (shared role).
# ----------------------------------------------------------------------------
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

# ----------------------------------------------------------------------------
# Routes on the shared external REST API.
# ----------------------------------------------------------------------------
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
