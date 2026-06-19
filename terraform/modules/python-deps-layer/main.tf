# Replicates serverless-python-requirements (dockerizePip:true, slim, strip):
# build a Python dependencies layer from a requirements.txt, optionally inside
# the AWS Lambda build image so native wheels match the Lambda runtime.
#
# Requires Docker on the machine running Terraform when dockerize = true.

locals {
  reqs_hash    = filebase64sha256(var.requirements_path)
  layer_zip    = "${var.build_dir}/layer.zip"
  python_dir   = "${var.build_dir}/python"
  docker_image = "public.ecr.aws/sam/build-${var.runtime}:latest"
  docker_arch  = var.architecture == "arm64" ? "linux/arm64" : "linux/amd64"
}

resource "null_resource" "build" {
  triggers = {
    reqs_hash    = local.reqs_hash
    runtime      = var.runtime
    architecture = var.architecture
    dockerize    = tostring(var.dockerize)
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      rm -rf "${local.python_dir}" "${local.layer_zip}"
      mkdir -p "${local.python_dir}"

      if [ "${var.dockerize}" = "true" ]; then
        docker run --rm --platform ${local.docker_arch} \
          -v "${abspath(var.build_dir)}":/out \
          -v "${var.requirements_path}":/tmp/requirements.txt:ro \
          --entrypoint /bin/sh \
          ${local.docker_image} \
          -c "pip install --no-cache-dir -r /tmp/requirements.txt -t /out/python && \
              find /out/python -type d -name '__pycache__' -prune -exec rm -rf {} + && \
              find /out/python -type d -name 'tests' -prune -exec rm -rf {} + && \
              find /out/python \\( -name '*.pyc' -o -name '*.pyo' \\) -delete"
      else
        pip install --no-cache-dir -r "${var.requirements_path}" -t "${local.python_dir}"
        find "${local.python_dir}" -type d -name '__pycache__' -prune -exec rm -rf {} + || true
      fi

      ( cd "${var.build_dir}" && zip -qr "layer.zip" "python" )
    EOT
  }
}

resource "aws_lambda_layer_version" "this" {
  layer_name          = var.layer_name
  filename            = local.layer_zip
  compatible_runtimes = [var.runtime]
  source_code_hash    = local.reqs_hash

  depends_on = [null_resource.build]
}
