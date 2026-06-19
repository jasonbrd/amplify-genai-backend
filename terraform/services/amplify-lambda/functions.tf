locals {
  # Base environment applied to every function (provider.environment).
  base_environment = merge(var.shared_env, {
    SERVICE_NAME               = local.service_name
    DEP_REGION                 = var.region
    MAX_CHUNKS                 = "1000"
    API_GATEWAY_MAX_TIMEOUT_MS = data.aws_ssm_parameter.api_gateway_max_timeout_ms.value
    APP_ARN_NAME               = data.aws_ssm_parameter.app_arn_name.value
    PANDOC_LAYER               = local.pandoc_layer_arn

    # Local resource names
    ACCOUNTS_DYNAMO_TABLE              = local.accounts_table
    ENV_VARS_TRACKING_TABLE            = local.env_vars_tracking_table
    CHAT_USAGE_DYNAMO_TABLE            = local.chat_usage_table
    CONVERSATION_METADATA_TABLE        = local.conversation_metadata_table
    DB_CONNECTIONS_TABLE               = local.db_connections_table
    FILES_DYNAMO_TABLE                 = local.files_table
    HASH_FILES_DYNAMO_TABLE            = local.hash_files_table
    LAMBDA_IAM_POLICY_NAME             = local.lambda_iam_policy_name
    S3_ACCESS_LOGS_BUCKET_NAME         = local.access_logs_bucket
    S3_SHARE_BUCKET_NAME               = local.share_bucket
    S3_CONVERSATIONS_BUCKET_NAME       = local.conversations_bucket
    S3_CONVERSION_INPUT_BUCKET_NAME    = local.conversion_input_bucket
    S3_CONVERSION_OUTPUT_BUCKET_NAME   = local.conversion_output_bucket
    S3_FILE_TEXT_BUCKET_NAME           = local.file_text_bucket
    S3_IMAGE_INPUT_BUCKET_NAME         = local.image_input_bucket
    S3_RAG_CHUNKS_BUCKET_NAME          = local.rag_chunks_bucket
    S3_RAG_INPUT_BUCKET_NAME           = local.rag_input_bucket
    S3_CONSOLIDATION_BUCKET_NAME       = local.consolidation_bucket
    SHARES_DYNAMODB_TABLE              = local.shares_table
    SQS_RAG_CHUNK_DOCUMENT_INDEX_QUEUE = local.rag_chunk_document_queue
    SQS_RAG_DOCUMENT_INDEX_QUEUE       = local.rag_document_index_queue
    USER_TAGS_DYNAMO_TABLE             = local.user_tags_table
    USER_STORAGE_TABLE                 = local.user_storage_table
    POLL_STATUS_TABLE                  = local.poll_status_table

    # Cross-service (producer module outputs)
    ADDITIONAL_CHARGES_TABLE       = var.chat_billing_params["ADDITIONAL_CHARGES_TABLE"]
    AMPLIFY_ADMIN_DYNAMODB_TABLE   = var.admin_params["AMPLIFY_ADMIN_DYNAMODB_TABLE"]
    API_KEYS_DYNAMODB_TABLE        = var.object_access_params["API_KEYS_DYNAMODB_TABLE"]
    COGNITO_USERS_DYNAMODB_TABLE   = var.object_access_params["COGNITO_USERS_DYNAMODB_TABLE"]
    COST_CALCULATIONS_DYNAMO_TABLE = var.amplify_js_params["COST_CALCULATIONS_DYNAMO_TABLE"]
    CRITICAL_ERRORS_SQS_QUEUE_NAME = var.admin_params["CRITICAL_ERRORS_SQS_QUEUE_NAME"]
    EMBEDDING_PROGRESS_TABLE       = var.embedding_params["EMBEDDING_PROGRESS_TABLE"]
    ASSISTANT_GROUPS_DYNAMO_TABLE  = var.object_access_params["ASSISTANT_GROUPS_DYNAMO_TABLE"]
    OBJECT_ACCESS_DYNAMODB_TABLE   = var.object_access_params["OBJECT_ACCESS_DYNAMODB_TABLE"]
    OPS_DYNAMODB_TABLE             = var.lambda_ops_params["OPS_DYNAMODB_TABLE"]
    DATA_DISCLOSURE_VERSIONS_TABLE = var.data_disclosure_params["DATA_DISCLOSURE_VERSIONS_TABLE"]
  })

  # Per-function extra env (queue URLs only known after the queues exist).
  extra_env = {
    process_document_for_rag   = { RAG_CHUNK_DOCUMENT_QUEUE_URL = aws_sqs_queue.rag_chunk_document.url }
    reprocess_document_for_rag = { RAG_PROCESS_DOCUMENT_QUEUE_URL = aws_sqs_queue.rag_document_index.url }
  }

  extended_timeout_fns = toset(["chat_endpoint"])

  # kind: http | sqs | schedule | s3 ; layer: deps | markitdown | convert
  functions = {
    user_data_router              = { handler = "state/user_data.route", timeout = 30, memory_size = 1024, kind = "http", path = "user-data/{proxy+}", method = "POST", cors = true, layer = "deps" }
    tools_op                      = { handler = "tools_ops.api_tools_handler", timeout = 30, memory_size = 1024, kind = "http", path = "state/register_ops", method = "POST", cors = true, layer = "deps" }
    chat_endpoint                 = { handler = "chat/service.chat_endpoint", timeout = 180, memory_size = 1024, kind = "http", path = "chat", method = "POST", cors = true, layer = "deps" }
    register_conversation         = { handler = "state/conversation.register_conversation", timeout = 6, memory_size = 1024, kind = "http", path = "state/conversation/register", method = "POST", cors = true, layer = "deps" }
    upload_conversation           = { handler = "state/conversation.upload_conversation", timeout = 6, memory_size = 1024, kind = "http", path = "state/conversation/upload", method = "PUT", cors = true, layer = "deps" }
    delete_conversation           = { handler = "state/conversation.delete_conversation", timeout = 10, memory_size = 1024, kind = "http", path = "state/conversation/delete", method = "DELETE", cors = true, layer = "deps" }
    delete_multiple_conversations = { handler = "state/conversation.delete_multiple_conversations", timeout = 29, memory_size = 1024, kind = "http", path = "state/conversation/delete_multiple", method = "POST", cors = true, layer = "deps" }
    get_conversation              = { handler = "state/conversation.get_conversation", timeout = 6, memory_size = 1024, kind = "http", path = "state/conversation/get", method = "GET", cors = true, layer = "deps" }
    get_multiple_conversations    = { handler = "state/conversation.get_multiple_conversations", timeout = 30, memory_size = 1024, kind = "http", path = "state/conversation/get/multiple", method = "POST", cors = true, layer = "deps" }
    get_all_conversation          = { handler = "state/conversation.get_all_conversations", timeout = 30, memory_size = 1024, kind = "http", path = "state/conversation/get/all", method = "GET", cors = true, layer = "deps" }
    get_empty_conversation        = { handler = "state/conversation.get_empty_conversations", timeout = 30, memory_size = 1024, kind = "http", path = "state/conversation/get/empty", method = "GET", cors = true, layer = "deps" }
    get_poll_status               = { handler = "utilities/poll_status.get_poll_status_handler", timeout = 30, memory_size = 1024, kind = "http", path = "poll/status", method = "GET", cors = true, layer = "deps" }
    upload_file                   = { handler = "files/file.get_presigned_url", timeout = 90, memory_size = 1024, kind = "http", path = "files/upload", method = "POST", cors = true, layer = "deps" }
    download_file                 = { handler = "files/file.get_presigned_download_url", timeout = 6, memory_size = 1024, kind = "http", path = "files/download", method = "POST", cors = true, layer = "deps" }
    delete_file                   = { handler = "files/file.delete_file", timeout = 30, memory_size = 1024, kind = "http", path = "files/delete", method = "POST", cors = true, layer = "deps" }
    list_tags_user                = { handler = "files/file.list_tags_for_user", timeout = 6, memory_size = 1024, kind = "http", path = "files/tags/list", method = "GET", cors = true, layer = "deps" }
    create_tags_user              = { handler = "files/file.create_tags", timeout = 6, memory_size = 1024, kind = "http", path = "files/tags/create", method = "POST", cors = true, layer = "deps" }
    delete_tag_user               = { handler = "files/file.delete_tag_from_user", timeout = 6, memory_size = 1024, kind = "http", path = "files/tags/delete", method = "POST", cors = true, layer = "deps" }
    set_tags_user_files           = { handler = "files/file.update_item_tags", timeout = 6, memory_size = 1024, kind = "http", path = "files/set_tags", method = "POST", cors = true, layer = "deps" }
    query_user_files              = { handler = "files/file.query_user_files", timeout = 30, memory_size = 1024, kind = "http", path = "files/query", method = "POST", cors = true, layer = "deps" }
    set_datasource_metadata       = { handler = "files/file.set_datasource_metadata_entry", timeout = 30, memory_size = 1024, kind = "http", path = "datasource/metadata/set", method = "POST", cors = true, layer = "deps" }
    user_share_with_users         = { handler = "state/share.share_with_users", timeout = 30, memory_size = 1024, kind = "http", path = "state/share", method = "POST", cors = false, layer = "deps" }
    user_share_load               = { handler = "state/share.load_data_from_s3", timeout = 30, memory_size = 1024, kind = "http", path = "state/share/load", method = "POST", cors = false, layer = "deps" }
    user_get_shares               = { handler = "state/share.get_share_data_for_user", timeout = 30, memory_size = 1024, kind = "http", path = "state/share", method = "GET", cors = false, layer = "deps" }
    chat_convert                  = { handler = "converters/docconverter.submit_conversion_job", timeout = 30, memory_size = 1024, kind = "http", path = "chat/convert", method = "POST", cors = false, layer = "deps" }
    accounts_get                  = { handler = "accounts/accounts.get_accounts", timeout = 6, memory_size = 1024, kind = "http", path = "state/accounts/get", method = "GET", cors = false, layer = "deps" }
    accounts_save                 = { handler = "accounts/accounts.save_accounts", timeout = 6, memory_size = 1024, kind = "http", path = "state/accounts/save", method = "POST", cors = false, layer = "deps" }
    settings_get                  = { handler = "state/usersettings.get_settings", timeout = 6, memory_size = 1024, kind = "http", path = "state/settings/get", method = "GET", cors = false, layer = "deps" }
    settings_save                 = { handler = "state/usersettings.save_settings", timeout = 6, memory_size = 1024, kind = "http", path = "state/settings/save", method = "POST", cors = false, layer = "deps" }
    reprocess_document_for_rag    = { handler = "files/file.reprocess_document_for_rag", timeout = 6, memory_size = 1024, kind = "http", path = "files/reprocess/rag", method = "POST", cors = false, layer = "deps" }
    test_db_connection            = { handler = "utilities/test_db_connection.lambda_handler", timeout = 6, memory_size = 1024, kind = "http", path = "db/test-connection", method = "POST", cors = true, layer = "deps" }
    save_db_connection            = { handler = "utilities/save_db_connection.lambda_handler", timeout = 6, memory_size = 1024, kind = "http", path = "db/save-connection", method = "POST", cors = true, layer = "deps" }
    get_db_connections            = { handler = "utilities/get_db_connections.lambda_handler", timeout = 30, memory_size = 1024, kind = "http", path = "db/get-connections", method = "POST", cors = true, layer = "deps" }

    process_document_for_rag      = { handler = "rag/core.process_document_for_rag", timeout = 300, memory_size = 1024, kind = "sqs", path = "", method = "", cors = false, layer = "markitdown" }
    process_document_for_chunking = { handler = "rag/core.chunk_document_for_rag", timeout = 300, memory_size = 1024, kind = "sqs", path = "", method = "", cors = false, layer = "markitdown" }

    archive_chat_usage         = { handler = "utilities/amplify-lambda/utilities/chat_usage_archive.archive_items", timeout = 6, memory_size = 1024, kind = "schedule", path = "", method = "", cors = false, layer = "deps" }
    cleanup_missed_rag_secrets = { handler = "rag/rag_secrets.lambda_handler", timeout = 300, memory_size = 1024, kind = "schedule", path = "", method = "", cors = false, layer = "deps" }

    convert                 = { handler = "converters/docconverter.handler", timeout = 180, memory_size = 1024, kind = "s3", path = "", method = "", cors = false, layer = "convert" }
    handlePptxUpload        = { handler = "powerpoints/core.handle_pptx_upload", timeout = 180, memory_size = 512, kind = "s3", path = "", method = "", cors = false, layer = "deps" }
    process_images_for_chat = { handler = "images/core.process_images_for_chat", timeout = 300, memory_size = 512, kind = "s3", path = "", method = "", cors = false, layer = "markitdown" }
    convertDataDisclosure   = { handler = "data_disclosure/convert.convert_uploaded_data_disclosure", timeout = 180, memory_size = 1024, kind = "s3", path = "", method = "", cors = false, layer = "markitdown" }
  }

  http_functions = { for k, f in local.functions : k => f if f.kind == "http" }
}

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
  layer_arns       = local.layer_arns[each.value.layer]
  environment      = merge(local.base_environment, lookup(local.extra_env, each.key, {}))
  role_arn         = aws_iam_role.lambda.arn
}
