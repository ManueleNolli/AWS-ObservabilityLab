provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.project
      Stack     = "main"
      ManagedBy = "terraform"
    }
  }
}

# Only for reading AWS's public list of service regions, which isn't published in opt-in regions
# such as Zurich.
provider "aws" {
  alias  = "global_infrastructure"
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

locals {
  self_hosted = var.monitoring_mode == "self_hosted"

  # ECR in var.region: the original in the bootstrap region, the replica anywhere else. Every image is
  # built from the same commit, so they share one tag.
  images = {
    for name in ["backend", "prometheus", "loki", "grafana", "fluent-bit", "adot"] :
    name => "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.project}/${name}:${var.image_tag}"
  }

  # Baked into the Prometheus, Grafana, Fluent Bit and ADOT configs in infrastructure/images/.
  service_discovery_namespace = "observability.internal"
}

module "network" {
  source = "../modules/network"

  name                        = var.project
  managed_prometheus_endpoint = !local.self_hosted
}

# Private DNS for the services: backend.observability.internal, prometheus.…, loki.…
resource "aws_service_discovery_private_dns_namespace" "this" {
  name = local.service_discovery_namespace
  vpc  = module.network.vpc_id
}

# Shared by the backend and the monitoring services, self-hosted or the managed-mode collector.
resource "aws_ecs_cluster" "this" {
  name = var.project

  # Billed per metric; the lab's own monitoring stack covers the same ground.
  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

module "backend" {
  source = "../modules/backend"

  name                           = "${var.project}-backend"
  vpc_id                         = module.network.vpc_id
  subnet_ids                     = module.network.private_subnet_ids
  cluster_id                     = aws_ecs_cluster.this.id
  image                          = local.images["backend"]
  service_discovery_namespace_id = aws_service_discovery_private_dns_namespace.this.id

  # Self-hosted: logs go to Loki through FireLens, with a copy in CloudWatch.
  log_router = local.self_hosted ? {
    image     = local.images["fluent-bit"]
    loki_host = "loki.${local.service_discovery_namespace}"
  } : null
}

module "cdn" {
  source = "../modules/cdn"

  name                  = var.project
  alb_arn               = module.backend.alb_arn
  alb_dns_name          = module.backend.alb_dns_name
  alb_security_group_id = module.backend.alb_security_group_id
  # /grafana on its own too: Grafana redirects it to /grafana/.
  alb_path_patterns = local.self_hosted ? ["/api/*", "/grafana", "/grafana/*"] : ["/api/*"]
}

module "monitoring" {
  source = "../modules/monitoring"
  count  = local.self_hosted ? 1 : 0

  name                           = var.project
  vpc_id                         = module.network.vpc_id
  subnet_ids                     = module.network.private_subnet_ids
  cluster_id                     = aws_ecs_cluster.this.id
  service_discovery_namespace_id = aws_service_discovery_private_dns_namespace.this.id
  images = {
    prometheus = local.images["prometheus"]
    loki       = local.images["loki"]
    grafana    = local.images["grafana"]
  }
  alb_listener_arn          = module.backend.alb_listener_arn
  alb_security_group_id     = module.backend.alb_security_group_id
  backend_security_group_id = module.backend.tasks_security_group_id
  backend_metrics_port      = module.backend.metrics_port
  grafana_root_url          = "${module.cdn.url}/grafana/"
}

module "managed_monitoring" {
  source = "../modules/managed-monitoring"
  count  = local.self_hosted ? 0 : 1

  name                      = var.project
  vpc_id                    = module.network.vpc_id
  subnet_ids                = module.network.private_subnet_ids
  cluster_id                = aws_ecs_cluster.this.id
  collector_image           = local.images["adot"]
  backend_security_group_id = module.backend.tasks_security_group_id
  backend_metrics_port      = module.backend.metrics_port
  alert_rules_file          = "${path.root}/../../observability/rules/app-alerts.yml"
}
