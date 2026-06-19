# The SHARED REST API. Serverless auto-created this from amplify-lambda's http
# events and exported its id as ${stage}-RestApiId. Terraform now owns it; the
# existing API (e.g. dkx9108zuc) is imported. All other service modules attach
# their routes to this API via the module outputs (rest_api_id / root_resource_id).
#
# Serverless default REST API name is "<stage>-<service>".
resource "aws_api_gateway_rest_api" "shared" {
  name = "${var.stage}-${local.service_name}"

  endpoint_configuration {
    types = ["EDGE"]
  }

  # Serverless manages binary media types / minimum compression by default off;
  # adjust here after the import diff is reviewed.
}
