# Builds a Lambda deployment package with dependencies VENDORED into the zip
# (serverless-python-requirements WITHOUT layer:true). Source files and the
# pip-installed deps live together at the package root.
#
# Requires Docker when dockerize = true (deps compiled in the Lambda build image).

locals {
  reqs_hash      = filebase64sha256(var.requirements_path)
  pkg_dir        = "${var.build_dir}/package"
  pkg_zip        = "${var.build_dir}/package.zip"
  docker_image   = "public.ecr.aws/sam/build-${var.runtime}:latest"
  docker_arch    = var.architecture == "arm64" ? "linux/arm64" : "linux/amd64"
  rsync_excludes = join(" ", [for e in var.excludes : "--exclude='${e}'"])
}

# Source-only archive, used purely to derive a stable content hash of the source.
data "archive_file" "src" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${var.build_dir}/source.zip"
  excludes    = var.excludes
}

resource "null_resource" "build" {
  triggers = {
    src_hash     = data.archive_file.src.output_base64sha256
    reqs_hash    = local.reqs_hash
    runtime      = var.runtime
    architecture = var.architecture
    dockerize    = tostring(var.dockerize)
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      rm -rf "${local.pkg_dir}" "${local.pkg_zip}"
      mkdir -p "${local.pkg_dir}"

      # Copy source (excluding build/dev artifacts) into the package root.
      rsync -a ${local.rsync_excludes} "${var.source_dir}/" "${local.pkg_dir}/"

      # Vendor dependencies alongside the source.
      if [ "${var.dockerize}" = "true" ]; then
        docker run --rm --platform ${local.docker_arch} \
          -v "${abspath(local.pkg_dir)}":/out \
          -v "${var.requirements_path}":/tmp/requirements.txt:ro \
          --entrypoint /bin/sh \
          ${local.docker_image} \
          -c "pip install --no-cache-dir -r /tmp/requirements.txt -t /out && \
              find /out -type d -name '__pycache__' -prune -exec rm -rf {} + && \
              find /out \\( -name '*.pyc' -o -name '*.pyo' \\) -delete"
      else
        pip install --no-cache-dir -r "${var.requirements_path}" -t "${local.pkg_dir}"
        find "${local.pkg_dir}" -type d -name '__pycache__' -prune -exec rm -rf {} + || true
      fi

      ( cd "${local.pkg_dir}" && zip -qr "${abspath(local.pkg_zip)}" . )
    EOT
  }
}
