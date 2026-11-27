variable "name" {
  description = "Name of the workspace, and prefix of its IAM role."
  type        = string
}

variable "prometheus_workspace_arn" {
  description = "Amazon Managed Prometheus workspace the Grafana role may query."
  type        = string
}

variable "admin_user_name" {
  description = "IAM Identity Center user name (UserName) that gets the Admin role in the workspace."
  type        = string
}
