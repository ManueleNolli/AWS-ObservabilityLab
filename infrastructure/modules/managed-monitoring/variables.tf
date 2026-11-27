variable "name" {
  description = "Alias of the workspace, and prefix of the collector's service, roles and log groups."
  type        = string
}

variable "vpc_id" {
  description = "VPC of the collector task."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets for the collector task. They need the aps-workspaces VPC endpoint or a NAT gateway."
  type        = list(string)
}

variable "cluster_id" {
  description = "ECS cluster the collector runs in."
  type        = string
}

variable "collector_image" {
  description = "Full URI of the ADOT collector image, with its tag. Its config names the backend's Cloud Map host."
  type        = string
}

variable "backend_security_group_id" {
  description = "Security group of the backend tasks, scraped by the collector."
  type        = string
}

variable "backend_metrics_port" {
  description = "Port the backend tasks serve metrics on."
  type        = number
}

variable "alert_rules_file" {
  description = "Prometheus rule file uploaded to the workspace as a rule group namespace."
  type        = string
}
