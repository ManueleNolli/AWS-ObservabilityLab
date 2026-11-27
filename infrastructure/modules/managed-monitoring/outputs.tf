output "prometheus_workspace_id" {
  description = "ID of the Amazon Managed Prometheus workspace."
  value       = aws_prometheus_workspace.this.id
}

output "prometheus_workspace_arn" {
  description = "ARN of the Amazon Managed Prometheus workspace."
  value       = aws_prometheus_workspace.this.arn
}

output "prometheus_endpoint" {
  description = "Prometheus-compatible endpoint of the workspace, ending in a slash: the query URL for Grafana."
  value       = aws_prometheus_workspace.this.prometheus_endpoint
}
