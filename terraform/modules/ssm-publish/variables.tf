variable "base_path" {
  description = "SSM path prefix to publish under, e.g. /amplify/dev/amplify-foo-data-disclosure"
  type        = string
}

variable "parameters" {
  description = "Map of KEY => value to publish as String parameters at <base_path>/<KEY>."
  type        = map(string)
}

variable "tier" {
  description = "SSM parameter tier."
  type        = string
  default     = "Standard"
}
