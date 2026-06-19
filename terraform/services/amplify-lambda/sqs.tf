# ---- RAG document index queue (+ DLQ) ----
resource "aws_sqs_queue" "rag_document_index_dlq" {
  name                      = "${local.rag_document_index_queue}-dlq"
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "rag_document_index" {
  name                       = local.rag_document_index_queue
  visibility_timeout_seconds = 300
  message_retention_seconds  = 86400
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.rag_document_index_dlq.arn
    maxReceiveCount     = 5
  })
}

# ---- RAG chunk document queue (+ DLQ) ----
resource "aws_sqs_queue" "rag_chunk_document_dlq" {
  name                      = "${local.rag_chunk_document_queue}-dlq"
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "rag_chunk_document" {
  name                       = local.rag_chunk_document_queue
  visibility_timeout_seconds = 300
  message_retention_seconds  = 86400
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.rag_chunk_document_dlq.arn
    maxReceiveCount     = 5
  })
}

# ---- Embedding chunks index queue (+ DLQ). Consumed by the embedding service. ----
resource "aws_sqs_queue" "embedding_chunks_dlq" {
  name                       = local.embedding_chunks_dlq
  visibility_timeout_seconds = 120
}

resource "aws_sqs_queue" "embedding_chunks" {
  name                       = local.embedding_chunks_queue
  visibility_timeout_seconds = 120
  message_retention_seconds  = 86400
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.embedding_chunks_dlq.arn
    maxReceiveCount     = 5
  })
}

# ---- Queue policies allowing S3 buckets to publish notifications ----
data "aws_iam_policy_document" "rag_document_index_queue_policy" {
  statement {
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.rag_document_index.arn]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = ["${local.s3a}${local.rag_input_bucket}"]
    }
  }
}

resource "aws_sqs_queue_policy" "rag_document_index" {
  queue_url = aws_sqs_queue.rag_document_index.id
  policy    = data.aws_iam_policy_document.rag_document_index_queue_policy.json
}

data "aws_iam_policy_document" "embedding_chunks_queue_policy" {
  statement {
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.embedding_chunks.arn]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = ["${local.s3a}${local.rag_chunks_bucket}"]
    }
  }
}

resource "aws_sqs_queue_policy" "embedding_chunks" {
  queue_url = aws_sqs_queue.embedding_chunks.id
  policy    = data.aws_iam_policy_document.embedding_chunks_queue_policy.json
}
