# amplify-lambda publishes the largest set of cross-service names (replaces its
# parameter_store_populator custom resource). The same map is exposed as the
# `published_params` module output so sibling modules can consume these names
# directly (no SSM data-source read needed on a fresh deploy). Every value is a
# pure function of name_prefix + stage, so the output creates no dependency cycle.
locals {
  published_params = {
    ACCOUNTS_DYNAMO_TABLE              = local.accounts_table
    ENV_VARS_TRACKING_TABLE            = local.env_vars_tracking_table
    CHAT_USAGE_DYNAMO_TABLE            = local.chat_usage_table
    CONVERSATION_METADATA_TABLE        = local.conversation_metadata_table
    DB_CONNECTIONS_TABLE               = local.db_connections_table
    FILES_DYNAMO_TABLE                 = local.files_table
    HASH_FILES_DYNAMO_TABLE            = local.hash_files_table
    USER_TAGS_DYNAMO_TABLE             = local.user_tags_table
    USER_STORAGE_TABLE                 = local.user_storage_table
    POLL_STATUS_TABLE                  = local.poll_status_table
    SHARES_DYNAMODB_TABLE              = local.shares_table
    S3_SHARE_BUCKET_NAME               = local.share_bucket
    S3_CONVERSATIONS_BUCKET_NAME       = local.conversations_bucket
    S3_CONVERSION_INPUT_BUCKET_NAME    = local.conversion_input_bucket
    S3_CONVERSION_OUTPUT_BUCKET_NAME   = local.conversion_output_bucket
    S3_FILE_TEXT_BUCKET_NAME           = local.file_text_bucket
    S3_IMAGE_INPUT_BUCKET_NAME         = local.image_input_bucket
    S3_RAG_CHUNKS_BUCKET_NAME          = local.rag_chunks_bucket
    S3_RAG_INPUT_BUCKET_NAME           = local.rag_input_bucket
    S3_CONSOLIDATION_BUCKET_NAME       = local.consolidation_bucket
    SQS_RAG_DOCUMENT_INDEX_QUEUE       = local.rag_document_index_queue
    SQS_RAG_CHUNK_DOCUMENT_INDEX_QUEUE = local.rag_chunk_document_queue
  }
}

module "ssm_publish" {
  source     = "../../modules/ssm-publish"
  base_path  = "${var.ssm_shared_path}/${local.service_name}"
  parameters = local.published_params
}
