locals {
  service_name = "${var.name_prefix}-lambda"
  src_dir      = "${path.module}/../../../amplify-lambda"
  build_dir    = "${path.root}/build/amplify-lambda"

  # ---- Local resource names (match ${self:service}-${sls:stage}-*) ----
  accounts_table              = "${local.service_name}-${var.stage}-accounts"
  env_vars_tracking_table     = "${local.service_name}-${var.stage}-env-vars-tracking"
  chat_usage_table            = "${local.service_name}-${var.stage}-chat-usage"
  conversation_metadata_table = "${local.service_name}-${var.stage}-conversation-metadata"
  db_connections_table        = "${local.service_name}-${var.stage}-db-connections"
  files_table                 = "${local.service_name}-${var.stage}-user-files"
  hash_files_table            = "${local.service_name}-${var.stage}-hash-files"
  user_tags_table             = "${local.service_name}-${var.stage}-user-tags"
  user_storage_table          = "${local.service_name}-${var.stage}-user-data-storage"
  poll_status_table           = "${local.service_name}-${var.stage}-poll-status"
  shares_table                = "${local.service_name}-${var.stage}" # SHARES_DYNAMODB_TABLE (marked for deletion)

  lambda_iam_policy_name = "${local.service_name}-${var.stage}-lambda-policy"

  # Buckets
  access_logs_bucket       = "${local.service_name}-${var.stage}-access-logs"
  share_bucket             = "${local.service_name}-${var.stage}-share"                      # marked for deletion
  conversations_bucket     = "${local.service_name}-${var.stage}-user-conversations"         # marked for deletion
  conversion_input_bucket  = "${local.service_name}-${var.stage}-document-conversion-input"  # marked for deletion
  conversion_output_bucket = "${local.service_name}-${var.stage}-document-conversion-output" # marked for deletion
  file_text_bucket         = "${local.service_name}-${var.stage}-file-text"
  image_input_bucket       = "${local.service_name}-${var.stage}-image-input"
  rag_chunks_bucket        = "${local.service_name}-${var.stage}-rag-chunks"
  rag_input_bucket         = "${local.service_name}-${var.stage}-rag-input"
  consolidation_bucket     = "${local.service_name}-${var.stage}-consolidation"

  # Queues
  rag_document_index_queue = "${local.service_name}-${var.stage}-rag-document-index-queue"
  rag_chunk_document_queue = "${local.service_name}-${var.stage}-rag-document-chunk-queue"
  embedding_chunks_queue   = "${local.service_name}-${var.stage}-embedding-chunks-index-queue"
  embedding_chunks_dlq     = "${local.service_name}-${var.stage}-embedding-chunks-index-dlq"
}
