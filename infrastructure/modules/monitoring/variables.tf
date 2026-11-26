variable "name" {
  description = "Prefix of the services, roles, buckets and log group: <name>-prometheus, <name>-loki, …"
  type        = string
}

variable "vpc_id" {
  description = "VPC of the tasks."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets for the tasks."
  type        = list(string)
}

variable "cluster_id" {
  description = "ECS cluster the services run in."
  type        = string
}

variable "service_discovery_namespace_id" {
  description = "Cloud Map namespace Prometheus and Loki register in. Its name is baked into the images' config."
  type        = string
}

variable "images" {
  description = "Full image URIs, with tags."
  type = object({
    prometheus = string
    loki       = string
    grafana    = string
  })
}

variable "alb_listener_arn" {
  description = "ALB listener that gets the /grafana/ rule."
  type        = string
}

variable "alb_security_group_id" {
  description = "Security group of the ALB."
  type        = string
}

variable "backend_security_group_id" {
  description = "Security group of the backend tasks: scraped by Prometheus, pushing logs to Loki."
  type        = string
}

variable "backend_metrics_port" {
  description = "Port the backend tasks serve metrics on."
  type        = number
}

variable "grafana_root_url" {
  description = "Public URL Grafana is served at, with the /grafana/ path."
  type        = string
}
