# Tables with SSEEnabled:false in the original omit server_side_encryption here
# (AWS-owned key default == SSEEnabled:false). UserStorage and PollStatus set SSE.

# SHARES_DYNAMODB_TABLE (marked for deletion)
resource "aws_dynamodb_table" "user_state" {
  name         = local.shares_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  attribute {
    name = "id"
    type = "S"
  }
  attribute {
    name = "user"
    type = "S"
  }
  attribute {
    name = "name"
    type = "S"
  }
  global_secondary_index {
    name            = "UserIndex"
    hash_key        = "user"
    projection_type = "ALL"
  }
  global_secondary_index {
    name            = "UserNameIndex"
    hash_key        = "user"
    range_key       = "name"
    projection_type = "ALL"
  }
  point_in_time_recovery { enabled = true }
}

resource "aws_dynamodb_table" "user_files" {
  name         = local.files_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  attribute {
    name = "id"
    type = "S"
  }
  attribute {
    name = "createdBy"
    type = "S"
  }
  attribute {
    name = "createdAt"
    type = "S"
  }
  attribute {
    name = "type"
    type = "S"
  }
  attribute {
    name = "name"
    type = "S"
  }
  global_secondary_index {
    name            = "createdBy"
    hash_key        = "createdBy"
    range_key       = "id"
    projection_type = "ALL"
  }
  global_secondary_index {
    name            = "createdByAndAt"
    hash_key        = "createdBy"
    range_key       = "createdAt"
    projection_type = "ALL"
  }
  global_secondary_index {
    name            = "createdByAndType"
    hash_key        = "createdBy"
    range_key       = "type"
    projection_type = "ALL"
  }
  global_secondary_index {
    name            = "createdByAndName"
    hash_key        = "createdBy"
    range_key       = "name"
    projection_type = "ALL"
  }
  point_in_time_recovery { enabled = true }
}

resource "aws_dynamodb_table" "user_tags" {
  name         = local.user_tags_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user"
  attribute {
    name = "user"
    type = "S"
  }
  point_in_time_recovery { enabled = true }
}

resource "aws_dynamodb_table" "hash_files" {
  name         = local.hash_files_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  attribute {
    name = "id"
    type = "S"
  }
  attribute {
    name = "textLocationKey"
    type = "S"
  }
  global_secondary_index {
    name            = "TextLocationIndex"
    hash_key        = "textLocationKey"
    projection_type = "ALL"
  }
  point_in_time_recovery { enabled = true }
}

resource "aws_dynamodb_table" "accounts" {
  name         = local.accounts_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user"
  attribute {
    name = "user"
    type = "S"
  }
  point_in_time_recovery { enabled = true }
}

resource "aws_dynamodb_table" "chat_usage" {
  name             = local.chat_usage_table
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "id"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"
  attribute {
    name = "id"
    type = "S"
  }
  attribute {
    name = "user"
    type = "S"
  }
  attribute {
    name = "time"
    type = "S"
  }
  global_secondary_index {
    name            = "UserUsageTimeIndex"
    hash_key        = "user"
    range_key       = "time"
    projection_type = "ALL"
  }
  global_secondary_index {
    name            = "DateIndex"
    hash_key        = "time"
    projection_type = "ALL"
  }
  point_in_time_recovery { enabled = true }
}

resource "aws_dynamodb_table" "conversation_metadata" {
  name         = local.conversation_metadata_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  range_key    = "conversation_id"
  attribute {
    name = "user_id"
    type = "S"
  }
  attribute {
    name = "conversation_id"
    type = "S"
  }
  attribute {
    name = "last_modified"
    type = "N"
  }
  global_secondary_index {
    name            = "TimestampIndex"
    hash_key        = "user_id"
    range_key       = "last_modified"
    projection_type = "ALL"
  }
  point_in_time_recovery { enabled = true }
}

resource "aws_dynamodb_table" "db_connections" {
  name         = local.db_connections_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  attribute {
    name = "id"
    type = "S"
  }
  attribute {
    name = "user"
    type = "S"
  }
  global_secondary_index {
    name            = "UserIndex"
    hash_key        = "user"
    projection_type = "ALL"
  }
  point_in_time_recovery { enabled = true }
}

resource "aws_dynamodb_table" "env_vars_tracking" {
  name         = local.env_vars_tracking_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "service_var_key"
  attribute {
    name = "service_var_key"
    type = "S"
  }
  attribute {
    name = "service_name"
    type = "S"
  }
  global_secondary_index {
    name            = "ServiceIndex"
    hash_key        = "service_name"
    projection_type = "ALL"
  }
  point_in_time_recovery { enabled = true }
}

resource "aws_dynamodb_table" "user_storage" {
  name         = local.user_storage_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"
  attribute {
    name = "PK"
    type = "S"
  }
  attribute {
    name = "SK"
    type = "S"
  }
  attribute {
    name = "UUID"
    type = "S"
  }
  global_secondary_index {
    name            = "UUID-index"
    hash_key        = "UUID"
    projection_type = "ALL"
  }
  point_in_time_recovery { enabled = true }
  server_side_encryption { enabled = true }
}

resource "aws_dynamodb_table" "poll_status" {
  name         = local.poll_status_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "requestId"
  range_key    = "user"
  attribute {
    name = "requestId"
    type = "S"
  }
  attribute {
    name = "user"
    type = "S"
  }
  attribute {
    name = "status"
    type = "S"
  }
  attribute {
    name = "createdAt"
    type = "S"
  }
  global_secondary_index {
    name            = "user-createdAt-index"
    hash_key        = "user"
    range_key       = "createdAt"
    projection_type = "ALL"
  }
  global_secondary_index {
    name            = "status-index"
    hash_key        = "status"
    projection_type = "ALL"
  }
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
  point_in_time_recovery { enabled = true }
  server_side_encryption { enabled = true }
}
