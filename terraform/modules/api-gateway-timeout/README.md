# api-gateway-timeout (replacement note)

In Serverless, the `ApiGatewayTimeoutConfig` custom resource invoked the
`runtime_config_manager` Lambda **after deploy** to PATCH API Gateway integration
timeouts above the 29s default (e.g. the `chat` endpoint at 180s). It existed
only because Serverless `http` events did not expose the integration timeout.

In Terraform this is **native** — set it directly on the integration. No custom
resource, no post-deploy Lambda, no `${stage}-RuntimeConfigManagerArn` export.

Pass `timeout_ms` on the route in the `rest-api-route` module:

```hcl
routes = [
  {
    path          = "chat"
    method        = "POST"
    invoke_arn    = module.chat_fn.invoke_arn
    function_name = module.chat_fn.function_name
    cors          = true
    timeout_ms    = 180000   # was applied by runtime_config_manager
  },
]
```

This maps to `aws_api_gateway_integration.timeout_milliseconds`.

> Note: integration timeouts above 29,000 ms require an AWS service-quota
> increase on the REST API ("Maximum integration timeout in milliseconds"),
> the same prerequisite the old manager assumed. Track per-stage in tfvars/SSM.

Retire during Phase 3:
- `amplify-lambda/utilities/runtime_config_manager.py` Lambda + its IAM policy
- the `ApiGatewayTimeoutConfig` custom resources in every service
- the `${stage}-RuntimeConfigManagerArn` CloudFormation export
