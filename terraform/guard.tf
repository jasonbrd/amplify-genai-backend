# Fail fast at plan/apply (NOT at validate) if the workspace is not a known
# stage, so nobody deploys from the implicit "default" workspace.
resource "terraform_data" "stage_guard" {
  lifecycle {
    precondition {
      condition     = contains(local.valid_stages, local.stage)
      error_message = "Select a workspace of dev|staging|prod first: `terraform workspace select <stage>` (current workspace: '${terraform.workspace}')."
    }
  }
}
