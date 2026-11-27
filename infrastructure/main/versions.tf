terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    grafana = {
      source  = "grafana/grafana"
      version = "~> 4.55"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
