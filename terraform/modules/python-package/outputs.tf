output "package_path" {
  description = "Path to the built deployment zip (source + vendored deps)."
  value       = local.pkg_zip
  depends_on  = [null_resource.build]
}

# Stable hash that changes when source OR requirements change. Used as the
# Lambda source_code_hash (the real zip is produced by the build provisioner).
output "source_code_hash" {
  value = base64sha256("${data.archive_file.src.output_base64sha256}:${local.reqs_hash}")
}
