# Access-logs target bucket + policy (other buckets log into it).
resource "aws_s3_bucket" "access_logs" {
  bucket = local.access_logs_bucket
}

data "aws_iam_policy_document" "access_logs" {
  statement {
    sid       = "S3ServerAccessLogsPolicy"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${local.s3a}${local.access_logs_bucket}/S3AccessLogs/*"]
    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }
}

resource "aws_s3_bucket_policy" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  policy = data.aws_iam_policy_document.access_logs.json
}

locals {
  # Buckets that log into the access-logs bucket, with their CORS methods.
  logged_buckets = {
    state             = { name = local.share_bucket, methods = ["PUT", "POST"] }                    # marked for deletion
    conversion_input  = { name = local.conversion_input_bucket, methods = ["GET"] }                 # marked for deletion
    conversion_output = { name = local.conversion_output_bucket, methods = ["GET", "PUT", "POST"] } # marked for deletion
    rag_input         = { name = local.rag_input_bucket, methods = ["GET", "PUT", "POST"] }
    image_input       = { name = local.image_input_bucket, methods = ["GET", "PUT", "POST"] }
    rag_chunks        = { name = local.rag_chunks_bucket, methods = ["GET"] }
    file_text         = { name = local.file_text_bucket, methods = ["GET", "HEAD"] }
    conversations     = { name = local.conversations_bucket, methods = ["PUT", "DELETE", "GET"] } # marked for deletion
  }
}

resource "aws_s3_bucket" "logged" {
  for_each = local.logged_buckets
  bucket   = each.value.name
}

resource "aws_s3_bucket_cors_configuration" "logged" {
  for_each = local.logged_buckets
  bucket   = aws_s3_bucket.logged[each.key].id
  cors_rule {
    allowed_origins = ["*"]
    allowed_methods = each.value.methods
    allowed_headers = ["*"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_logging" "logged" {
  for_each      = local.logged_buckets
  bucket        = aws_s3_bucket.logged[each.key].id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "S3AccessLogs/"
}

# ---- Consolidation bucket (versioned, lifecycle, PAB, 3 lambda notifications) ----
resource "aws_s3_bucket" "consolidation" {
  bucket = local.consolidation_bucket
}

resource "aws_s3_bucket_cors_configuration" "consolidation" {
  bucket = aws_s3_bucket.consolidation.id
  cors_rule {
    allowed_origins = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE"]
    allowed_headers = ["*"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_logging" "consolidation" {
  bucket        = aws_s3_bucket.consolidation.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "S3AccessLogs/"
}

resource "aws_s3_bucket_versioning" "consolidation" {
  bucket = aws_s3_bucket.consolidation.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "consolidation" {
  bucket                  = aws_s3_bucket.consolidation.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "consolidation" {
  bucket = aws_s3_bucket.consolidation.id
  rule {
    id     = "TempFilesCleanup"
    status = "Enabled"
    filter {
      prefix = "temp/"
    }
    expiration {
      days = 1
    }
  }
  rule {
    id     = "IntegrationFilesCleanup"
    status = "Enabled"
    filter {
      prefix = "tempIntegrationFiles/"
    }
    expiration {
      days = 1
    }
  }
  rule {
    id     = "ConversionCleanup"
    status = "Enabled"
    filter {
      prefix = "conversion/"
    }
    expiration {
      days = 1
    }
  }
}
