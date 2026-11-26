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
  description = "Backend image tag the stack is deployed with."
  value       = var.image_tag
}
