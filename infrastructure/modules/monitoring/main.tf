# Self-hosted monitoring on Fargate: Prometheus, Loki and Grafana, one task each. Their config is
# baked into the images (infrastructure/images/), the services find each other through Cloud Map,
# and Grafana is served at /grafana/ through the ALB.

locals {
  ports = {
    prometheus = 9090
    loki       = 3100
    grafana    = 3000
  }
}

data "aws_region" "current" {}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.name}-monitoring"
  retention_in_days = 7
}

data "aws_iam_policy_document" "ecs_tasks_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Used by ECS itself to pull the images and write the containers' logs.
resource "aws_iam_role" "execution" {
  name               = "${var.name}-monitoring-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# One group for the three services: they all talk to each other.
resource "aws_security_group" "this" {
  name_prefix = "${var.name}-monitoring-"
  description = "Prometheus, Loki and Grafana"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "self" {
  for_each = local.ports

  security_group_id            = aws_security_group.this.id
  description                  = "${each.key} from the other monitoring services"
  referenced_security_group_id = aws_security_group.this.id
  ip_protocol                  = "tcp"
  from_port                    = each.value
  to_port                      = each.value
}

# Fluent Bit, in the backend tasks, pushes the backend's logs.
resource "aws_vpc_security_group_ingress_rule" "loki_from_backend" {
  security_group_id            = aws_security_group.this.id
  description                  = "Loki from the backend's log router"
  referenced_security_group_id = var.backend_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = local.ports.loki
  to_port                      = local.ports.loki
}

resource "aws_vpc_security_group_ingress_rule" "grafana_from_alb" {
  security_group_id            = aws_security_group.this.id
  description                  = "Grafana from the ALB"
  referenced_security_group_id = var.alb_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = local.ports.grafana
  to_port                      = local.ports.grafana
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  description       = "All outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# The other side of the rules above.

resource "aws_vpc_security_group_ingress_rule" "backend_metrics_from_prometheus" {
  security_group_id            = var.backend_security_group_id
  description                  = "Metrics, scraped by Prometheus"
  referenced_security_group_id = aws_security_group.this.id
  ip_protocol                  = "tcp"
  from_port                    = var.backend_metrics_port
  to_port                      = var.backend_metrics_port
}

resource "aws_vpc_security_group_egress_rule" "alb_to_grafana" {
  security_group_id            = var.alb_security_group_id
  description                  = "To Grafana"
  referenced_security_group_id = aws_security_group.this.id
  ip_protocol                  = "tcp"
  from_port                    = local.ports.grafana
  to_port                      = local.ports.grafana
}

# Prometheus and Loki are reached by name: prometheus.<namespace>, loki.<namespace>.
resource "aws_service_discovery_service" "this" {
  for_each = toset(["prometheus", "loki"])

  name = each.key

  dns_config {
    namespace_id = var.service_discovery_namespace_id

    dns_records {
      type = "A"
      ttl  = 10
    }
  }
}
