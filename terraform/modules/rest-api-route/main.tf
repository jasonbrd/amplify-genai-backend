locals {
  # Expand each route path into its cumulative prefixes so every path segment
  # becomes an API Gateway resource exactly once.
  #   "data-disclosure/check" -> ["data-disclosure", "data-disclosure/check"]
  path_prefixes = distinct(flatten([
    for r in var.routes : [
      for i in range(length(split("/", r.path))) :
      join("/", slice(split("/", r.path), 0, i + 1))
    ]
  ]))

  # For each prefix: the last path part and its parent prefix ("" = root).
  resources = {
    for p in local.path_prefixes : p => {
      part   = element(split("/", p), length(split("/", p)) - 1)
      parent = length(split("/", p)) == 1 ? "" : join("/", slice(split("/", p), 0, length(split("/", p)) - 1))
    }
  }

  # Methods keyed by "METHOD path".
  methods = {
    for r in var.routes : "${upper(r.method)} ${r.path}" => r
  }

  # Resources that need a CORS OPTIONS method (any route on them sets cors=true).
  cors_paths = distinct([for r in var.routes : r.path if r.cors])

  # Hash of this service's route surface; drives the shared-stage redeploy and is
  # also exported so a future centralized deployment can aggregate it.
  redeploy_trigger = sha1(jsonencode({
    methods      = sort([for k in keys(local.methods) : k])
    integrations = sort([for k, r in local.methods : "${k}:${r.invoke_arn}:${coalesce(r.timeout_ms, 0)}"])
    cors         = sort(local.cors_paths)
  }))
}

resource "aws_api_gateway_resource" "this" {
  for_each = local.resources

  rest_api_id = var.rest_api_id
  parent_id   = each.value.parent == "" ? var.root_resource_id : aws_api_gateway_resource.this[each.value.parent].id
  path_part   = each.value.part
}

resource "aws_api_gateway_method" "this" {
  for_each = local.methods

  rest_api_id   = var.rest_api_id
  resource_id   = aws_api_gateway_resource.this[each.value.path].id
  http_method   = upper(each.value.method)
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "this" {
  for_each = local.methods

  rest_api_id             = var.rest_api_id
  resource_id             = aws_api_gateway_resource.this[each.value.path].id
  http_method             = aws_api_gateway_method.this[each.key].http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = each.value.invoke_arn
  timeout_milliseconds    = each.value.timeout_ms
}

resource "aws_lambda_permission" "this" {
  for_each = local.methods

  statement_id  = "AllowAPIGW-${replace(replace(each.key, " ", "-"), "/", "_")}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.region}:${var.account_id}:${var.rest_api_id}/*/${upper(each.value.method)}/${each.value.path}"
}

# ----------------------- CORS (OPTIONS mock) -----------------------
resource "aws_api_gateway_method" "options" {
  for_each = toset(local.cors_paths)

  rest_api_id   = var.rest_api_id
  resource_id   = aws_api_gateway_resource.this[each.value].id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options" {
  for_each = toset(local.cors_paths)

  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.this[each.value].id
  http_method = aws_api_gateway_method.options[each.value].http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options" {
  for_each = toset(local.cors_paths)

  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.this[each.value].id
  http_method = aws_api_gateway_method.options[each.value].http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options" {
  for_each = toset(local.cors_paths)

  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.this[each.value].id
  http_method = aws_api_gateway_method.options[each.value].http_method
  status_code = aws_api_gateway_method_response.options[each.value].status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,DELETE,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.options]
}

# ----------------------- Shared-stage redeploy -----------------------
# Each former Serverless stack created its own AWS::ApiGateway::Deployment to
# push its methods live on the shared stage. We replicate that with a redeploy
# triggered whenever this service's route surface changes. Using create-deployment
# (rather than an aws_api_gateway_deployment/stage resource) avoids multiple
# services fighting over ownership of the externally-managed stage during the
# incremental migration.
resource "null_resource" "deploy" {
  count = var.create_deployment ? 1 : 0

  triggers = {
    redeploy = local.redeploy_trigger
  }

  provisioner "local-exec" {
    command = "aws apigateway create-deployment --rest-api-id ${var.rest_api_id} --stage-name ${var.stage_name} --region ${var.region} --description 'tf redeploy ${local.redeploy_trigger}'"
  }

  depends_on = [
    aws_api_gateway_integration.this,
    aws_api_gateway_integration_response.options,
    aws_lambda_permission.this,
  ]
}
