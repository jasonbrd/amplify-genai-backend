provider "aws" {
  region = var.dep_region

  default_tags {
    tags = merge(
      {
        ManagedBy  = "terraform"
        Repo       = "amplify-genai-backend"
        Stage      = local.stage
        Deployment = var.dep_name
      },
      var.default_tags,
    )
  }
}
