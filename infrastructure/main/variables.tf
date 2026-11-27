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

variable "grafana_admin_user_name" {
  description = "managed mode: IAM Identity Center user name that gets the Admin role in Amazon Managed Grafana."
  type        = string
  default     = null

  validation {
    # Deploy passes an empty string when the repository variable isn't set.
    condition     = var.monitoring_mode != "managed" || try(length(var.grafana_admin_user_name), 0) > 0
    error_message = "monitoring_mode = \"managed\" needs grafana_admin_user_name: your IAM Identity Center user name."
  }
}

variable "identity_center_region" {
  description = "managed mode: region of the IAM Identity Center instance. Defaults to region."
  type        = string
  default     = null
}
