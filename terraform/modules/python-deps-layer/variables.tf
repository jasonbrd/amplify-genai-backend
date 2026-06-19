variable "layer_name" {
  description = "Name of the Lambda layer version."
  type        = string
}

variable "requirements_path" {
  description = "Absolute path to the requirements.txt to install into the layer."
  type        = string
}

variable "runtime" {
  description = "Python runtime (compatible runtime for the layer)."
  type        = string
  default     = "python3.11"
}

variable "architecture" {
  description = "Lambda architecture for the layer build image."
  type        = string
  default     = "x86_64"

  validation {
    condition     = contains(["x86_64", "arm64"], var.architecture)
    error_message = "architecture must be x86_64 or arm64."
  }
}

variable "build_dir" {
  description = "Directory where the layer is built and zipped. Should be gitignored."
  type        = string
}

variable "dockerize" {
  description = "Build deps inside the AWS sam-build/lambda image (matches serverless-python-requirements dockerizePip:true). Requires Docker on the machine running terraform."
  type        = bool
  default     = true
}
