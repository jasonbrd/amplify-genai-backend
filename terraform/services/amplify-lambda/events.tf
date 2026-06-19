# ---- HTTP routes on the shared API (this service owns the API) ----
module "routes" {
  source           = "../../modules/rest-api-route"
  rest_api_id      = aws_api_gateway_rest_api.shared.id
  root_resource_id = aws_api_gateway_rest_api.shared.root_resource_id
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

# ---- SQS event-source mappings ----
resource "aws_lambda_event_source_mapping" "process_document_for_rag" {
  event_source_arn = aws_sqs_queue.rag_document_index.arn
  function_name    = module.fn["process_document_for_rag"].function_arn
  batch_size       = 1
}

resource "aws_lambda_event_source_mapping" "process_document_for_chunking" {
  event_source_arn = aws_sqs_queue.rag_chunk_document.arn
  function_name    = module.fn["process_document_for_chunking"].function_arn
}

# ---- Scheduled tasks ----
resource "aws_cloudwatch_event_rule" "archive_chat_usage" {
  name                = "${local.service_name}-${var.stage}-archive-chat-usage"
  schedule_expression = "cron(0 0 ? * SUN *)"
}
resource "aws_cloudwatch_event_target" "archive_chat_usage" {
  rule = aws_cloudwatch_event_rule.archive_chat_usage.name
  arn  = module.fn["archive_chat_usage"].function_arn
}
resource "aws_lambda_permission" "archive_chat_usage" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = module.fn["archive_chat_usage"].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.archive_chat_usage.arn
}

resource "aws_cloudwatch_event_rule" "cleanup_missed_rag_secrets" {
  name                = "${local.service_name}-${var.stage}-cleanup-rag-secrets"
  schedule_expression = "cron(0 3 * * ? *)"
}
resource "aws_cloudwatch_event_target" "cleanup_missed_rag_secrets" {
  rule = aws_cloudwatch_event_rule.cleanup_missed_rag_secrets.name
  arn  = module.fn["cleanup_missed_rag_secrets"].function_arn
}
resource "aws_lambda_permission" "cleanup_missed_rag_secrets" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = module.fn["cleanup_missed_rag_secrets"].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cleanup_missed_rag_secrets.arn
}

# ---- S3 -> Lambda permissions ----
resource "aws_lambda_permission" "process_images_from_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = module.fn["process_images_for_chat"].function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "${local.s3a}${local.image_input_bucket}"
}

resource "aws_lambda_permission" "convert_from_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = module.fn["convert"].function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "${local.s3a}${local.consolidation_bucket}"
}

resource "aws_lambda_permission" "handle_pptx_from_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = module.fn["handlePptxUpload"].function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "${local.s3a}${local.consolidation_bucket}"
}

resource "aws_lambda_permission" "convert_dd_from_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = module.fn["convertDataDisclosure"].function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "${local.s3a}${local.consolidation_bucket}"
}

# ---- S3 bucket notifications ----
resource "aws_s3_bucket_notification" "image_input" {
  bucket = aws_s3_bucket.logged["image_input"].id
  lambda_function {
    lambda_function_arn = module.fn["process_images_for_chat"].function_arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.process_images_from_s3]
}

resource "aws_s3_bucket_notification" "rag_input" {
  bucket = aws_s3_bucket.logged["rag_input"].id
  queue {
    queue_arn = aws_sqs_queue.rag_document_index.arn
    events    = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_sqs_queue_policy.rag_document_index]
}

resource "aws_s3_bucket_notification" "rag_chunks" {
  bucket = aws_s3_bucket.logged["rag_chunks"].id
  queue {
    queue_arn = aws_sqs_queue.embedding_chunks.arn
    events    = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_sqs_queue_policy.embedding_chunks]
}

resource "aws_s3_bucket_notification" "consolidation" {
  bucket = aws_s3_bucket.consolidation.id

  lambda_function {
    lambda_function_arn = module.fn["convert"].function_arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "conversion/input/"
  }
  lambda_function {
    lambda_function_arn = module.fn["handlePptxUpload"].function_arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "powerPointTemplates/"
    filter_suffix       = ".pptx"
  }
  lambda_function {
    lambda_function_arn = module.fn["convertDataDisclosure"].function_arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "dataDisclosure/"
    filter_suffix       = ".pdf"
  }

  depends_on = [
    aws_lambda_permission.convert_from_s3,
    aws_lambda_permission.handle_pptx_from_s3,
    aws_lambda_permission.convert_dd_from_s3,
  ]
}
