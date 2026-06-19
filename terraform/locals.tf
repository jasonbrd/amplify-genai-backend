locals {
  # Stage is the Terraform workspace. We forbid the implicit "default" workspace
  # so nobody accidentally deploys an unstaged state.
  stage = terraform.workspace

  valid_stages = ["dev", "staging", "prod"]

  # Naming: services are named amplify-<dep_name>-<service> (matches Serverless
  # `service: amplify-${depName}-<svc>`).
  name_prefix = "amplify-${var.dep_name}"

  # SSM layout (matches the v0.9.0 Parameter Store scheme):
  #   shared config:        /amplify/<stage>/<KEY>
  #   per-service published: /amplify/<stage>/<service-name>/<KEY>
  #   cross-service base:    /amplify/<stage>/amplify-<dep_name>  (+ "-<svc>/<KEY>")
  ssm_shared_path = "/amplify/${local.stage}"
  ssm_base_path   = "/amplify/${local.stage}/${local.name_prefix}"
}
