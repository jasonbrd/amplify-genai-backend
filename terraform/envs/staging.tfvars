# staging stage inputs (use with: terraform workspace select staging && terraform apply -var-file=envs/staging.tfvars)
# Mirror the not-in-SSM values from var/staging-var.yml (that file is not committed).
# Fill in the real DEP_NAME/region before applying.

dep_name   = "REPLACE_ME" # DEP_NAME from var/staging-var.yml (1-9 chars, no spaces)
dep_region = "us-east-1"
log_level  = "INFO"

default_tags = {
  Environment = "staging"
}

# ---- Custom API domain (optional overrides) ----
# custom_domain_enabled is true by default (amplify-lambda manages the domain).
# Set the cert ARN only if dep_region is not us-east-1 or auto-discovery fails.
# api_custom_domain_certificate_arn = ""
# route53_zone_id                   = ""
