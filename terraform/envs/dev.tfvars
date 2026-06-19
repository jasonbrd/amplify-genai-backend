# dev stage inputs (use with: terraform workspace select dev && terraform apply -var-file=envs/dev.tfvars)
# Mirrors the not-in-SSM values from var/dev-var.yml.

dep_name   = "afai" # DEP_NAME from var/dev-var.yml
dep_region = "us-east-1"
log_level  = "INFO"

default_tags = {
  Environment = "dev"
}
