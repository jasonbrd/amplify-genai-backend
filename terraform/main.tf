# Service modules are wired here. Each maps 1:1 to a former Serverless service.
# Modules are added incrementally as each service is migrated and its existing
# resources are imported into state (see scripts/import/).
#
# Ordering mirrors serverless-compose `dependsOn`. Terraform resolves implicit
# dependencies through references; add explicit `depends_on` only where a hard
# ordering exists that is not expressed by a reference.

module "amplify_lambda" {
  source = "./services/amplify-lambda"

  chat_billing_params    = module.chat_billing.published_params
  admin_params           = module.amplify_lambda_admin.published_params
  object_access_params   = module.object_access.published_params
  amplify_js_params      = module.amplify_lambda_js.published_params
  embedding_params       = module.embedding.published_params
  lambda_ops_params      = module.amplify_lambda_ops.published_params
  data_disclosure_params = module.data_disclosure.published_params

  # Custom API domain (replaces serverless-domain-manager). Domain value comes
  # from the shared SSM CUSTOM_API_DOMAIN read in data.tf.
  custom_api_domain                 = data.aws_ssm_parameter.custom_api_domain.value
  custom_domain_enabled             = var.custom_domain_enabled
  api_custom_domain_certificate_arn = var.api_custom_domain_certificate_arn
  route53_zone_id                   = var.route53_zone_id

  stage       = local.stage
  region      = local.region
  account_id  = local.account_id
  partition   = local.partition
  name_prefix = local.name_prefix

  ssm_shared_path = local.ssm_shared_path
  ssm_base_path   = local.ssm_base_path
  shared_env      = local.shared_env
}

module "data_disclosure" {
  source = "./services/data-disclosure"

  lambda_params        = module.amplify_lambda.published_params
  object_access_params = module.object_access.published_params
  chat_billing_params  = module.chat_billing.published_params
  amplify_js_params    = module.amplify_lambda_js.published_params
  admin_params         = module.amplify_lambda_admin.published_params

  stage       = local.stage
  region      = local.region
  account_id  = local.account_id
  partition   = local.partition
  name_prefix = local.name_prefix

  rest_api_id               = local.rest_api_id
  rest_api_root_resource_id = local.rest_api_root_resource_id

  ssm_shared_path = local.ssm_shared_path
  ssm_base_path   = local.ssm_base_path
  shared_env      = local.shared_env
}

module "object_access" {
  source = "./services/object-access"

  lambda_params       = module.amplify_lambda.published_params
  chat_billing_params = module.chat_billing.published_params
  admin_params        = module.amplify_lambda_admin.published_params
  amplify_js_params   = module.amplify_lambda_js.published_params

  stage       = local.stage
  region      = local.region
  account_id  = local.account_id
  partition   = local.partition
  name_prefix = local.name_prefix

  rest_api_id               = local.rest_api_id
  rest_api_root_resource_id = local.rest_api_root_resource_id

  ssm_shared_path = local.ssm_shared_path
  ssm_base_path   = local.ssm_base_path
  shared_env      = local.shared_env
}

# module "amplify_lambda"  { ... }  # Phase 3 (foundational)
# module "amplify_lambda_js" { ... }
# ... remaining services

module "chat_billing" {
  source = "./services/chat-billing"

  lambda_params        = module.amplify_lambda.published_params
  admin_params         = module.amplify_lambda_admin.published_params
  object_access_params = module.object_access.published_params
  amplify_js_params    = module.amplify_lambda_js.published_params
  lambda_ops_params    = module.amplify_lambda_ops.published_params

  stage       = local.stage
  region      = local.region
  account_id  = local.account_id
  partition   = local.partition
  name_prefix = local.name_prefix

  rest_api_id               = local.rest_api_id
  rest_api_root_resource_id = local.rest_api_root_resource_id

  ssm_shared_path = local.ssm_shared_path
  ssm_base_path   = local.ssm_base_path
  shared_env      = local.shared_env
}

module "amplify_lambda_artifacts" {
  source = "./services/amplify-lambda-artifacts"

  stage       = local.stage
  region      = local.region
  account_id  = local.account_id
  partition   = local.partition
  name_prefix = local.name_prefix

  rest_api_id               = local.rest_api_id
  rest_api_root_resource_id = local.rest_api_root_resource_id

  ssm_shared_path = local.ssm_shared_path
  ssm_base_path   = local.ssm_base_path
  shared_env      = local.shared_env

  lambda_params        = module.amplify_lambda.published_params
  object_access_params = module.object_access.published_params
  chat_billing_params  = module.chat_billing.published_params
  amplify_js_params    = module.amplify_lambda_js.published_params
  admin_params         = module.amplify_lambda_admin.published_params
}

module "amplify_lambda_ops" {
  source = "./services/amplify-lambda-ops"

  lambda_params        = module.amplify_lambda.published_params
  object_access_params = module.object_access.published_params
  chat_billing_params  = module.chat_billing.published_params
  amplify_js_params    = module.amplify_lambda_js.published_params
  admin_params         = module.amplify_lambda_admin.published_params

  stage       = local.stage
  region      = local.region
  account_id  = local.account_id
  partition   = local.partition
  name_prefix = local.name_prefix

  rest_api_id               = local.rest_api_id
  rest_api_root_resource_id = local.rest_api_root_resource_id

  ssm_shared_path = local.ssm_shared_path
  ssm_base_path   = local.ssm_base_path
  shared_env      = local.shared_env
}

module "amplify_lambda_api" {
  source = "./services/amplify-lambda-api"

  lambda_params        = module.amplify_lambda.published_params
  object_access_params = module.object_access.published_params
  chat_billing_params  = module.chat_billing.published_params
  amplify_js_params    = module.amplify_lambda_js.published_params
  admin_params         = module.amplify_lambda_admin.published_params
  lambda_ops_params    = module.amplify_lambda_ops.published_params

  stage       = local.stage
  region      = local.region
  account_id  = local.account_id
  partition   = local.partition
  name_prefix = local.name_prefix

  rest_api_id               = local.rest_api_id
  rest_api_root_resource_id = local.rest_api_root_resource_id

  ssm_shared_path = local.ssm_shared_path
  ssm_base_path   = local.ssm_base_path
  shared_env      = local.shared_env
}

# --- Deferred (non-leaf, complex) ---
module "amplify_lambda_admin" {
  source = "./services/amplify-lambda-admin"

  lambda_params        = module.amplify_lambda.published_params
  object_access_params = module.object_access.published_params
  chat_billing_params  = module.chat_billing.published_params
  amplify_js_params    = module.amplify_lambda_js.published_params

  dep_name    = var.dep_name
  stage       = local.stage
  region      = local.region
  account_id  = local.account_id
  partition   = local.partition
  name_prefix = local.name_prefix

  rest_api_id               = local.rest_api_id
  rest_api_root_resource_id = local.rest_api_root_resource_id

  ssm_shared_path = local.ssm_shared_path
  ssm_base_path   = local.ssm_base_path
  shared_env      = local.shared_env
}

# module "amplify_lambda"  { ... }  # Phase 3 (foundational; SQS/layers/custom resources)
# module "amplify_lambda_js" { ... }     # Node streaming
# module "embedding" / "amplify_assistants" / "agent_loop" { ... }

module "assistants_api" {
  source = "./services/amplify-lambda-assistants-api"

  lambda_params        = module.amplify_lambda.published_params
  object_access_params = module.object_access.published_params
  chat_billing_params  = module.chat_billing.published_params
  amplify_js_params    = module.amplify_lambda_js.published_params
  admin_params         = module.amplify_lambda_admin.published_params
  assistants_params    = module.amplify_assistants.published_params

  stage       = local.stage
  region      = local.region
  account_id  = local.account_id
  partition   = local.partition
  name_prefix = local.name_prefix

  rest_api_id               = local.rest_api_id
  rest_api_root_resource_id = local.rest_api_root_resource_id

  ssm_shared_path = local.ssm_shared_path
  ssm_base_path   = local.ssm_base_path
  shared_env      = local.shared_env
}

module "assistants_api_google" {
  source = "./services/amplify-lambda-assistants-api-google"

  lambda_params         = module.amplify_lambda.published_params
  object_access_params  = module.object_access.published_params
  chat_billing_params   = module.chat_billing.published_params
  amplify_js_params     = module.amplify_lambda_js.published_params
  admin_params          = module.amplify_lambda_admin.published_params
  assistants_api_params = module.assistants_api.published_params
  lambda_ops_params     = module.amplify_lambda_ops.published_params

  stage       = local.stage
  region      = local.region
  account_id  = local.account_id
  partition   = local.partition
  name_prefix = local.name_prefix

  rest_api_id               = local.rest_api_id
  rest_api_root_resource_id = local.rest_api_root_resource_id

  ssm_shared_path = local.ssm_shared_path
  ssm_base_path   = local.ssm_base_path
  shared_env      = local.shared_env

  # Cross-module: DynamoDB stream from the admin service (replaces the CFN export).
  admin_table_stream_arn = module.amplify_lambda_admin.admin_table_stream_arn
}

module "assistants_api_office365" {
  source = "./services/amplify-lambda-assistants-api-office365"

  lambda_params         = module.amplify_lambda.published_params
  object_access_params  = module.object_access.published_params
  chat_billing_params   = module.chat_billing.published_params
  amplify_js_params     = module.amplify_lambda_js.published_params
  admin_params          = module.amplify_lambda_admin.published_params
  assistants_api_params = module.assistants_api.published_params
  lambda_ops_params     = module.amplify_lambda_ops.published_params

  stage       = local.stage
  region      = local.region
  account_id  = local.account_id
  partition   = local.partition
  name_prefix = local.name_prefix

  rest_api_id               = local.rest_api_id
  rest_api_root_resource_id = local.rest_api_root_resource_id

  ssm_shared_path = local.ssm_shared_path
  ssm_base_path   = local.ssm_base_path
  shared_env      = local.shared_env

  admin_table_stream_arn = module.amplify_lambda_admin.admin_table_stream_arn
}

module "amplify_lambda_js" {
  source = "./services/amplify-lambda-js"

  lambda_params        = module.amplify_lambda.published_params
  object_access_params = module.object_access.published_params
  chat_billing_params  = module.chat_billing.published_params
  admin_params         = module.amplify_lambda_admin.published_params
  assistants_params    = module.amplify_assistants.published_params
  agent_loop_params    = module.amplify_agent_loop.published_params

  stage       = local.stage
  region      = local.region
  account_id  = local.account_id
  partition   = local.partition
  name_prefix = local.name_prefix

  rest_api_id               = local.rest_api_id
  rest_api_root_resource_id = local.rest_api_root_resource_id

  ssm_shared_path = local.ssm_shared_path
  ssm_base_path   = local.ssm_base_path
  shared_env      = local.shared_env
}

module "amplify_agent_loop" {
  source = "./services/amplify-agent-loop-lambda"

  lambda_params        = module.amplify_lambda.published_params
  object_access_params = module.object_access.published_params
  chat_billing_params  = module.chat_billing.published_params
  amplify_js_params    = module.amplify_lambda_js.published_params
  admin_params         = module.amplify_lambda_admin.published_params
  assistants_params    = module.amplify_assistants.published_params
  lambda_ops_params    = module.amplify_lambda_ops.published_params

  stage       = local.stage
  region      = local.region
  account_id  = local.account_id
  partition   = local.partition
  name_prefix = local.name_prefix

  rest_api_id               = local.rest_api_id
  rest_api_root_resource_id = local.rest_api_root_resource_id

  ssm_shared_path = local.ssm_shared_path
  ssm_base_path   = local.ssm_base_path
  shared_env      = local.shared_env
}

module "amplify_assistants" {
  source = "./services/amplify-assistants"

  lambda_params        = module.amplify_lambda.published_params
  chat_billing_params  = module.chat_billing.published_params
  object_access_params = module.object_access.published_params
  admin_params         = module.amplify_lambda_admin.published_params
  amplify_js_params    = module.amplify_lambda_js.published_params
  lambda_ops_params    = module.amplify_lambda_ops.published_params

  stage       = local.stage
  region      = local.region
  account_id  = local.account_id
  partition   = local.partition
  name_prefix = local.name_prefix

  rest_api_id               = local.rest_api_id
  rest_api_root_resource_id = local.rest_api_root_resource_id

  ssm_shared_path = local.ssm_shared_path
  ssm_base_path   = local.ssm_base_path
  shared_env      = local.shared_env
}

module "embedding" {
  source = "./services/embedding"

  lambda_params        = module.amplify_lambda.published_params
  chat_billing_params  = module.chat_billing.published_params
  admin_params         = module.amplify_lambda_admin.published_params
  object_access_params = module.object_access.published_params
  assistants_params    = module.amplify_assistants.published_params
  amplify_js_params    = module.amplify_lambda_js.published_params
  lambda_ops_params    = module.amplify_lambda_ops.published_params

  stage       = local.stage
  region      = local.region
  account_id  = local.account_id
  partition   = local.partition
  name_prefix = local.name_prefix

  rest_api_id               = local.rest_api_id
  rest_api_root_resource_id = local.rest_api_root_resource_id

  ssm_shared_path = local.ssm_shared_path
  ssm_base_path   = local.ssm_base_path
  shared_env      = local.shared_env

  # RAG/embedding queues owned by amplify-lambda.
  embedding_chunks_queue_arn   = module.amplify_lambda.embedding_chunks_queue_arn
  embedding_chunks_queue_url   = module.amplify_lambda.embedding_chunks_queue_url
  embedding_chunks_dlq_arn     = module.amplify_lambda.embedding_chunks_dlq_arn
  rag_chunk_document_queue_arn = module.amplify_lambda.rag_chunk_document_queue_arn
  rag_chunk_document_queue_url = module.amplify_lambda.rag_chunk_document_queue_url
}
