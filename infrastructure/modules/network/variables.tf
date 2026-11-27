variable "name" {
  description = "Name of the VPC and prefix of the resources in it."
  type        = string
}

variable "cidr" {
  description = "CIDR of the VPC, a /16: the subnets are carved out of it."
  type        = string
  default     = "10.0.0.0/16"
}

variable "managed_prometheus_endpoint" {
  description = "Adds an aps-workspaces interface endpoint, for remote writes to Amazon Managed Prometheus. Billed by the hour, so only when needed."
  type        = bool
  default     = false
}
