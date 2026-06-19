# Manual API Gateway streaming integration for chat_stream. Serverless defined
# this by hand because its http event can't express response streaming
# (ResponseTransferMode: STREAM + the /response-streaming-invocations URI).
resource "aws_api_gateway_resource" "chat_stream" {
  rest_api_id = var.rest_api_id
  parent_id   = var.rest_api_root_resource_id
  path_part   = "chat_stream"
}

resource "aws_api_gateway_method" "chat_stream_post" {
  rest_api_id   = var.rest_api_id
  resource_id   = aws_api_gateway_resource.chat_stream.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "chat_stream_post" {
  rest_api_id             = var.rest_api_id
  resource_id             = aws_api_gateway_resource.chat_stream.id
  http_method             = aws_api_gateway_method.chat_stream_post.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  # Response-streaming invocation endpoint (vs the normal /invocations).
  uri = "arn:${var.partition}:apigateway:${var.region}:lambda:path/2021-11-15/functions/${module.fn["chat_stream"].function_arn}/response-streaming-invocations"

  # NOTE: two streaming settings can't be expressed by the AWS Terraform provider
  # (v5) and must be applied once out-of-band after creation:
  #   - Integration.ResponseTransferMode = STREAM
  #   - TimeoutInMillis = 900000 (the provider validates timeout_milliseconds to a
  #     max of 300000, but response streaming supports up to 15 min)
  # via:
  #   aws apigateway update-integration --rest-api-id <id> --resource-id <rid> \
  #     --http-method POST --patch-operations \
  #       op=replace,path=/responseTransferMode,value=STREAM \
  #       op=replace,path=/timeoutInMillis,value=900000
  # Tracked in TERRAFORM_MIGRATION.md (provider gaps).
}

resource "aws_api_gateway_method_response" "chat_stream_post" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.chat_stream.id
  http_method = aws_api_gateway_method.chat_stream_post.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
    "method.response.header.Content-Type"                = true
  }
}

resource "aws_lambda_permission" "chat_stream" {
  statement_id  = "AllowAPIGWInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.fn["chat_stream"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:${var.partition}:execute-api:${var.region}:${var.account_id}:${var.rest_api_id}/*/*"
}

# CORS preflight for /chat_stream
resource "aws_api_gateway_method" "chat_stream_options" {
  rest_api_id   = var.rest_api_id
  resource_id   = aws_api_gateway_resource.chat_stream.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "chat_stream_options" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.chat_stream.id
  http_method = aws_api_gateway_method.chat_stream_options.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "chat_stream_options" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.chat_stream.id
  http_method = aws_api_gateway_method.chat_stream_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "chat_stream_options" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.chat_stream.id
  http_method = aws_api_gateway_method.chat_stream_options.http_method
  status_code = aws_api_gateway_method_response.chat_stream_options.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  depends_on = [aws_api_gateway_integration.chat_stream_options]
}
