variable "region" {
  description = "Region for every resource in this stack."
  type        = string
  default     = "eu-central-2"
}

variable "project" {
  description = "Prefix for resource names and value of the Project tag."
  type        = string
  default     = "observability-lab"
}

variable "monitoring_mode" {
  description = "self_hosted runs Prometheus, Loki and Grafana ourselves; managed uses Amazon Managed Prometheus and Grafana."
  type        = string
  default     = "self_hosted"

  validation {
    condition     = contains(["self_hosted", "managed"], var.monitoring_mode)
    error_message = "monitoring_mode must be self_hosted or managed."
  }
}

variable "image_tag" {
  description = "Tag of the images in ECR: the git SHA they were built from. Deploy sets it."
  type        = string

  validation {
    condition     = length(var.image_tag) > 0
    error_message = "image_tag must not be empty."
  }
}
