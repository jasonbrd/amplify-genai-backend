variable "source_dir" {
  description = "Service source directory to package."
  type        = string
}

variable "requirements_path" {
  description = "requirements.txt to vendor INTO the package (serverless-python-requirements without layer:true)."
  type        = string
}

variable "build_dir" {
  description = "Directory for build artifacts (gitignored)."
  type        = string
}

variable "runtime" {
  type    = string
  default = "python3.11"
}

variable "architecture" {
  type    = string
  default = "x86_64"
}

variable "dockerize" {
  description = "Install deps in the AWS Lambda build image (matches dockerizePip). Requires Docker."
  type        = bool
  default     = true
}

variable "excludes" {
  description = "Paths excluded from the source copy."
  type        = list(string)
  default     = ["serverless.yml", "requirements.txt", "node_modules", "venv", ".serverless", "package", "__pycache__", ".gitignore", ".idea", ".env.local"]
}
