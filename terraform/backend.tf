# Remote state in S3 with DynamoDB locking.
#
# Stage selection is driven by the Terraform WORKSPACE (dev | staging | prod),
# NOT by a `stage` variable. With `workspace_key_prefix`, each workspace gets an
# isolated state key:  <workspace_key_prefix>/<workspace>/terraform.tfstate
#
# One-time bootstrap (creates the state bucket + lock table) lives outside this
# config so it is never destroyed by an `apply` here. See terraform/README.md.
#
# The bucket/table names below are placeholders. Set the real values during
# Phase 1 bootstrap, or override at init time:
#
#   terraform init \
#     -backend-config="bucket=<your-tf-state-bucket>" \
#     -backend-config="dynamodb_table=<your-tf-lock-table>" \
#     -backend-config="region=us-east-1"
#
terraform {
  backend "s3" {
    bucket               = "amplify-genai-backend-tfstate"
    key                  = "terraform.tfstate"
    workspace_key_prefix = "amplify-genai-backend"
    region               = "us-east-1"
    dynamodb_table       = "amplify-genai-backend-tflock"
    encrypt              = true
  }
}
