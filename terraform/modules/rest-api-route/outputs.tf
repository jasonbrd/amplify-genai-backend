# Hash of this service's route surface. The root/global API-deployment resource
# aggregates these from every service so a single aws_api_gateway_deployment
# redeploys the (externally-owned) stage when any route changes. This avoids
# multiple per-service deployments fighting over one shared API.
output "redeploy_trigger" {
  value = local.redeploy_trigger
}

output "resource_ids" {
  description = "Map of path prefix -> API Gateway resource ID created by this service."
  value       = { for k, v in aws_api_gateway_resource.this : k => v.id }
}
