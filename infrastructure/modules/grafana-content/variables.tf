variable "region" {
  description = "Region of the AMP workspace and the CloudWatch data."
  type        = string
}

variable "prometheus_endpoint" {
  description = "Prometheus-compatible endpoint of the AMP workspace."
  type        = string
}

variable "backend_log_group_name" {
  description = "CloudWatch log group of the backend, queried by the Logs dashboard."
  type        = string
}

variable "backend_log_group_arn" {
  description = "ARN of the backend's log group, without the trailing :*."
  type        = string
}

variable "overview_dashboard_file" {
  description = "The shared Overview dashboard, observability/dashboards/app-overview.json."
  type        = string
}
