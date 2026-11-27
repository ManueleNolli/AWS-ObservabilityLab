output "url" {
  description = "URL of the workspace."
  value       = "https://${aws_grafana_workspace.this.endpoint}"
}

output "workspace_id" {
  description = "ID of the workspace."
  value       = aws_grafana_workspace.this.id
}

output "service_account_token" {
  description = "Admin token for Terraform's Grafana provider."
  value       = aws_grafana_workspace_service_account_token.terraform.key
  sensitive   = true
}
