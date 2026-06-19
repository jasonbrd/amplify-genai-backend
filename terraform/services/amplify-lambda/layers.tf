# PythonRequirementsLambdaLayer (serverless-python-requirements, layer:true).
module "deps_layer" {
  source            = "../../modules/python-deps-layer"
  layer_name        = "${local.service_name}-${var.stage}-python-requirements"
  requirements_path = "${local.src_dir}/requirements.txt"
  runtime           = "python3.11"
  architecture      = "x86_64"
  build_dir         = "${local.build_dir}/layer"
  dockerize         = true
}

# Markitdown layer. In Serverless this was a path-based layer (markitdown/),
# pre-built by markitdown/markitdown.sh. Here we rebuild its requirements into a
# layer. (If markitdown.sh does more than pip install, port that into the build.)
module "markitdown_layer" {
  source            = "../../modules/python-deps-layer"
  layer_name        = "${local.service_name}-${var.stage}-markitdown"
  requirements_path = "${local.src_dir}/markitdown/requirements.txt"
  runtime           = "python3.11"
  architecture      = "x86_64"
  build_dir         = "${local.build_dir}/markitdown-layer"
  dockerize         = true
}

locals {
  # Pandoc layer ARN is external (provided by the IaC via SSM).
  pandoc_layer_arn = data.aws_ssm_parameter.pandoc_layer_arn.value

  layer_arns = {
    deps       = [module.deps_layer.layer_arn]
    markitdown = [module.markitdown_layer.layer_arn]
    convert    = [local.pandoc_layer_arn, module.deps_layer.layer_arn]
  }
}
