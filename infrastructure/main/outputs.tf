# Read by the Deploy and Destroy workflows: the stack must be destroyed with the settings it was
# deployed with, and changing region needs a destroy first.
output "region" {
  description = "Region the stack is deployed to."
  value       = var.region
}

output "monitoring_mode" {
  description = "Monitoring mode the stack is deployed with."
  value       = var.monitoring_mode
}

output "image_tag" {
  description = "Image tag the stack is deployed with."
  value       = var.image_tag
}

# Read by Deploy to upload the frontend.

output "url" {
  description = "Public URL of the lab."
  value       = module.cdn.url
}

output "grafana_url" {
  description = "Grafana's URL, in self_hosted mode."
  value       = local.self_hosted ? "${module.cdn.url}/grafana" : null
}

output "prometheus_workspace_id" {
  description = "Amazon Managed Prometheus workspace, in managed mode."
  value       = local.self_hosted ? null : module.managed_monitoring[0].prometheus_workspace_id
}

output "frontend_bucket" {
  description = "Bucket the frontend build is uploaded to."
  value       = module.cdn.frontend_bucket
}

output "distribution_id" {
  description = "CloudFront distribution, for invalidations."
  value       = module.cdn.distribution_id
}
