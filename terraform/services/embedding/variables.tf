variable "stage" { type = string }
variable "region" { type = string }
variable "account_id" { type = string }
variable "partition" { type = string }
variable "name_prefix" { type = string }

variable "rest_api_id" { type = string }
variable "rest_api_root_resource_id" { type = string }

variable "ssm_shared_path" { type = string }
variable "ssm_base_path" { type = string }

variable "shared_env" {
  type = map(string)
}

variable "api_gateway_max_timeout_ms" {
  type    = number
  default = null
}

# ---- RAG/embedding queues from the amplify-lambda module ----
variable "embedding_chunks_queue_arn" { type = string }
variable "embedding_chunks_queue_url" { type = string }
variable "embedding_chunks_dlq_arn" { type = string }
variable "rag_chunk_document_queue_arn" { type = string }
variable "rag_chunk_document_queue_url" { type = string }

# ---- Producer module-output params (replace cross-service SSM reads) ----
variable "lambda_params" { type = map(string) }
variable "chat_billing_params" { type = map(string) }
variable "admin_params" { type = map(string) }
variable "object_access_params" { type = map(string) }
variable "assistants_params" { type = map(string) }
variable "amplify_js_params" { type = map(string) }
variable "lambda_ops_params" { type = map(string) }
