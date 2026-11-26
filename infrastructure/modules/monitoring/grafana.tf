# Grafana, public at /grafana/ through CloudFront and the ALB. Anonymous visitors are Viewers; nobody
# can log in, so nobody can change anything. Data sources and dashboards are provisioned from the
# image, so Grafana keeps no state worth saving.

# Nobody uses it: it replaces the default admin/admin, in case a login endpoint is still reachable.
resource "random_password" "grafana_admin" {
  length  = 32
  special = false
}

resource "aws_lb_target_group" "grafana" {
  name        = "${var.name}-grafana"
  vpc_id      = var.vpc_id
  target_type = "ip"
  protocol    = "HTTP"
  port        = local.ports.grafana

  deregistration_delay = 30

  health_check {
    path                = "/grafana/api/health"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener_rule" "grafana" {
  listener_arn = var.alb_listener_arn
  priority     = 10

  condition {
    path_pattern {
      values = ["/grafana", "/grafana/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }
}

resource "aws_ecs_task_definition" "grafana" {
  family                   = "${var.name}-grafana"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([{
    name         = "grafana"
    image        = var.images.grafana
    essential    = true
    portMappings = [{ containerPort = local.ports.grafana, protocol = "tcp" }]

    environment = [
      # Served under /grafana/ of the CloudFront URL.
      { name = "GF_SERVER_ROOT_URL", value = var.grafana_root_url },
      { name = "GF_SERVER_SERVE_FROM_SUB_PATH", value = "true" },
      # Read-only for everyone: no login form, no basic auth.
      { name = "GF_AUTH_ANONYMOUS_ENABLED", value = "true" },
      { name = "GF_AUTH_ANONYMOUS_ORG_ROLE", value = "Viewer" },
      { name = "GF_AUTH_DISABLE_LOGIN_FORM", value = "true" },
      { name = "GF_AUTH_BASIC_ENABLED", value = "false" },
      { name = "GF_SECURITY_ADMIN_PASSWORD", value = random_password.grafana_admin.result },
      { name = "GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH", value = "/var/lib/grafana/dashboards/app-overview.json" },
      { name = "GF_ANALYTICS_REPORTING_ENABLED", value = "false" },
      { name = "GF_ANALYTICS_CHECK_FOR_UPDATES", value = "false" },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.this.name
        awslogs-region        = data.aws_region.current.region
        awslogs-stream-prefix = "grafana"
      }
    }
  }])
}

resource "aws_ecs_service" "grafana" {
  name            = "${var.name}-grafana"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.grafana.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  health_check_grace_period_seconds = 60

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.this.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.grafana.arn
    container_name   = "grafana"
    container_port   = local.ports.grafana
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  wait_for_steady_state = true

  depends_on = [aws_lb_listener_rule.grafana]
}
