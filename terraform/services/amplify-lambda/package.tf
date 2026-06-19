# amplify-lambda uses layer:true, so the function package is source-only
# (dependencies ship in the deps layer).
data "archive_file" "package" {
  type        = "zip"
  source_dir  = local.src_dir
  output_path = "${local.build_dir}/package.zip"
  excludes = [
    "serverless.yml", "requirements.txt", "node_modules", "venv", ".serverless",
    "package", "__pycache__", ".gitignore", "markitdown",
  ]
}
