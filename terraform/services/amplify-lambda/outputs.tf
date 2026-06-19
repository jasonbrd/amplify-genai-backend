# The shared REST API (consumed by every other service module).
output "rest_api_id" {
  value = aws_api_gateway_rest_api.shared.id
}

output "root_resource_id" {
  value = aws_api_gateway_rest_api.shared.root_resource_id
}

# RAG / embedding queues (consumed by the embedding service; replaces the
# ${stage}-*QueueArn / *QueueUrl CloudFormation exports).
output "rag_document_index_queue_arn" {
  value = aws_sqs_queue.rag_document_index.arn
}
output "rag_document_index_queue_url" {
  value = aws_sqs_queue.rag_document_index.url
}
output "rag_chunk_document_queue_arn" {
  value = aws_sqs_queue.rag_chunk_document.arn
}
output "rag_chunk_document_queue_url" {
  value = aws_sqs_queue.rag_chunk_document.url
}
output "embedding_chunks_queue_arn" {
  value = aws_sqs_queue.embedding_chunks.arn
}
output "embedding_chunks_queue_url" {
  value = aws_sqs_queue.embedding_chunks.url
}
output "embedding_chunks_dlq_arn" {
  value = aws_sqs_queue.embedding_chunks_dlq.arn
}

# Chat-usage table stream (was exported as ${stage}-AccountingChatUsageDynamoStreamArn).
output "chat_usage_stream_arn" {
  value = aws_dynamodb_table.chat_usage.stream_arn
}

output "function_names" {
  value = { for k, m in module.fn : k => m.function_name }
}

output "published_ssm_parameters" {
  value = module.ssm_publish.parameter_names
}

output "redeploy_trigger" {
  value = module.routes.redeploy_trigger
}

# Cross-service resource names consumed directly by sibling modules (replaces
# the SSM data-source reads other services used to perform). Pure functions of
# name_prefix + stage, so referencing this output creates no dependency cycle.
output "published_params" {
  value = local.published_params
}
