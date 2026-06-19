locals {
  service_name = "${var.name_prefix}-data-disclosure" # amplify-<dep>-data-disclosure
  src_dir      = "${path.module}/../../../data-disclosure"
  build_dir    = "${path.root}/build/data-disclosure"

  # Locally-owned resource names (match `${self:service}-${sls:stage}-*`).
  acceptance_table = "${local.service_name}-${var.stage}-acceptance"
  versions_table   = "${local.service_name}-${var.stage}-versions"
  storage_bucket   = "${local.service_name}-${var.stage}-storage" # marked for future deletion
  policy_name      = "${local.service_name}-${var.stage}-iam-policy"

  # Locally-defined env vars published to SSM for other services to consume.
  published_params = {
    DATA_DISCLOSURE_ACCEPTANCE_TABLE = local.acceptance_table
    DATA_DISCLOSURE_VERSIONS_TABLE   = local.versions_table
    DATA_DISCLOSURE_STORAGE_BUCKET   = local.storage_bucket
    DATA_DISCLOSURE_IAM_POLICY_NAME  = local.policy_name
  }

  # Function definitions (handler/limits/route) — mirrors serverless.yml functions.
  functions = {
    check_dd_decision = {
      handler     = "data_disclosure.check_data_disclosure_decision"
      memory_size = 512
      timeout     = 30
      path        = "data-disclosure/check"
      method      = "GET"
      cors        = true
    }
    save_dd_decision = {
      handler     = "data_disclosure.save_data_disclosure_decision"
      memory_size = 1024 # Serverless default when unspecified
      timeout     = 30
      path        = "data-disclosure/save"
      method      = "POST"
      cors        = true
    }
    get_latest_dd = {
      handler     = "data_disclosure.get_latest_data_disclosure"
      memory_size = 1024 # Serverless default when unspecified
      timeout     = 30
      path        = "data-disclosure/latest"
      method      = "GET"
      cors        = true
    }
    upload_dd = {
      handler     = "data_disclosure.get_presigned_data_disclosure"
      memory_size = 1024 # Serverless default when unspecified
      timeout     = 10
      path        = "data-disclosure/upload"
      method      = "POST"
      cors        = true
    }
  }

  # Environment for every function = shared + local + cross-service (from SSM).
  environment = merge(var.shared_env, {
    SERVICE_NAME = local.service_name

    DATA_DISCLOSURE_ACCEPTANCE_TABLE = local.acceptance_table
    DATA_DISCLOSURE_VERSIONS_TABLE   = local.versions_table
    DATA_DISCLOSURE_STORAGE_BUCKET   = local.storage_bucket
    DATA_DISCLOSURE_IAM_POLICY_NAME  = local.policy_name

    ACCOUNTS_DYNAMO_TABLE          = var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]
    ADDITIONAL_CHARGES_TABLE       = var.chat_billing_params["ADDITIONAL_CHARGES_TABLE"]
    API_KEYS_DYNAMODB_TABLE        = var.object_access_params["API_KEYS_DYNAMODB_TABLE"]
    COGNITO_USERS_DYNAMODB_TABLE   = var.object_access_params["COGNITO_USERS_DYNAMODB_TABLE"]
    COST_CALCULATIONS_DYNAMO_TABLE = var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]
    CRITICAL_ERRORS_SQS_QUEUE_NAME = var.admin_params["CRITICAL_ERRORS_SQS_QUEUE_NAME"]
    ENV_VARS_TRACKING_TABLE        = var.lambda_params["ENV_VARS_TRACKING_TABLE"]
    S3_CONSOLIDATION_BUCKET_NAME   = var.lambda_params["S3_CONSOLIDATION_BUCKET_NAME"]
  })
}

# ----------------------------------------------------------------------------
# Cross-service values consumed from SSM (published by other services).
# Mirrors the `${ssm:${self:custom.ssmBasePath}-<svc>/<KEY>}` references.
# ----------------------------------------------------------------------------
# Cross-service SSM reads removed: now sourced from producer module-output variables.

# ----------------------------------------------------------------------------
# Packaging: source + vendored dependencies in one zip (serverless-python-
# requirements WITHOUT layer:true — deps ship inside the function package).
# ----------------------------------------------------------------------------
module "package" {
  source            = "../../modules/python-package"
  source_dir        = local.src_dir
  requirements_path = "${local.src_dir}/requirements.txt"
  build_dir         = local.build_dir
  runtime           = "python3.11"
  architecture      = "x86_64"
  dockerize         = true
}

# ----------------------------------------------------------------------------
# IAM: one managed policy (DataDisclosureIAMPolicy) + shared execution role.
# ----------------------------------------------------------------------------
data "aws_iam_policy_document" "service" {
  # NOTE: secretsmanager:GetSecretValue is grouped with the DynamoDB resources
  # exactly as in the original serverless.yml (preserved for parity; effectively
  # a no-op against table ARNs).
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "dynamodb:Query", "dynamodb:Scan", "dynamodb:GetItem",
      "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem",
    ]
    resources = [
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.versions_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.versions_table}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.acceptance_table}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${local.acceptance_table}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]}/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["API_KEYS_DYNAMODB_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]}",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["API_KEYS_DYNAMODB_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.lambda_params["ACCOUNTS_DYNAMO_TABLE"]}/index/*",
      "arn:${var.partition}:dynamodb:${var.region}:*:table/${var.object_access_params["COGNITO_USERS_DYNAMODB_TABLE"]}",
    ]
  }

  statement {
    effect  = "Allow"
    actions = ["s3:PutObject", "s3:GetObject", "s3:HeadObject", "s3:PutBucketNotification"]
    resources = [
      "arn:${var.partition}:s3:::${local.storage_bucket}",
      "arn:${var.partition}:s3:::${local.storage_bucket}/*",
      "arn:${var.partition}:s3:::${var.lambda_params["S3_CONSOLIDATION_BUCKET_NAME"]}",
      "arn:${var.partition}:s3:::${var.lambda_params["S3_CONSOLIDATION_BUCKET_NAME"]}/*",
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
  # Matches the Serverless-generated role name (region embedded) so the import
  # does not trigger a rename/replace.
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
# Stateful resources (IMPORT these; never recreate).
# ----------------------------------------------------------------------------
resource "aws_dynamodb_table" "acceptance" {
  name         = local.acceptance_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user"

  attribute {
    name = "user"
    type = "S"
  }
  point_in_time_recovery { enabled = true }
  server_side_encryption { enabled = true }
}

resource "aws_dynamodb_table" "versions" {
  name         = local.versions_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "key"
  range_key    = "version"

  attribute {
    name = "key"
    type = "S"
  }
  attribute {
    name = "version"
    type = "N"
  }
  point_in_time_recovery { enabled = true }
  server_side_encryption { enabled = true }
}

# Marked for future deletion in the original serverless.yml. Retained + imported
# so Terraform does not delete a live bucket. Remove in a later, deliberate step.
resource "aws_s3_bucket" "storage" {
  bucket = local.storage_bucket
}

resource "aws_s3_bucket_cors_configuration" "storage" {
  bucket = aws_s3_bucket.storage.id
  cors_rule {
    allowed_origins = ["*"]
    allowed_methods = ["GET", "PUT"]
    allowed_headers = ["*"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "storage" {
  bucket = aws_s3_bucket.storage.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
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
  package_path     = module.package.package_path
  source_code_hash = module.package.source_code_hash
  runtime          = "python3.11"
  timeout          = each.value.timeout
  memory_size      = each.value.memory_size
  layer_arns       = []
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
    }
  ]
}
