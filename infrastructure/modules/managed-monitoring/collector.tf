# The ADOT collector: one Fargate task that scrapes backend.<namespace>:<metrics port> and remote-writes
# to the workspace through the aps-workspaces VPC endpoint, signing with the task role. Its scrape and
# export config is baked into the image (infrastructure/images/adot/).

resource "aws_cloudwatch_log_group" "collector" {
  name              = "/ecs/${var.name}-collector"
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

# Used by ECS itself to pull the image and write the container's logs.
resource "aws_iam_role" "execution" {
  name               = "${var.name}-collector-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Assumed by the collector to sign its remote writes.
resource "aws_iam_role" "collector" {
  name               = "${var.name}-collector"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
}

data "aws_iam_policy_document" "collector" {
  statement {
    actions   = ["aps:RemoteWrite"]
    resources = [aws_prometheus_workspace.this.arn]
  }
}

resource "aws_iam_role_policy" "collector" {
  name   = "remote-write"
  role   = aws_iam_role.collector.id
  policy = data.aws_iam_policy_document.collector.json
}

# Nothing connects to the collector; it only connects out.
resource "aws_security_group" "collector" {
  name_prefix = "${var.name}-collector-"
  description = "ADOT collector"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

# Outbound to the backend's metrics port, the VPC endpoints and Cloud Map's DNS.
resource "aws_vpc_security_group_egress_rule" "collector_all" {
  security_group_id = aws_security_group.collector.id
  description       = "All outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "backend_metrics_from_collector" {
  security_group_id            = var.backend_security_group_id
  description                  = "Metrics, scraped by the ADOT collector"
  referenced_security_group_id = aws_security_group.collector.id
  ip_protocol                  = "tcp"
  from_port                    = var.backend_metrics_port
  to_port                      = var.backend_metrics_port
}

resource "aws_ecs_task_definition" "collector" {
  family                   = "${var.name}-collector"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.collector.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([{
    name      = "collector"
    image     = var.collector_image
    essential = true

    # Read by config.yaml.
    environment = [
      { name = "AMP_REMOTE_WRITE_URL", value = "${aws_prometheus_workspace.this.prometheus_endpoint}api/v1/remote_write" },
      { name = "AWS_REGION", value = data.aws_region.current.region },
    ]

    # The image's own binary, asking the health_check extension.
    healthCheck = {
      command     = ["/healthcheck"]
      interval    = 10
      timeout     = 3
      retries     = 3
      startPeriod = 10
    }

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.collector.name
        awslogs-region        = data.aws_region.current.region
        awslogs-stream-prefix = "collector"
      }
    }
  }])
}

resource "aws_ecs_service" "collector" {
  name            = "${var.name}-collector"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.collector.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  # Two collectors would write every sample twice: stop the old task before starting the new one.
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.collector.id]
    assign_public_ip = false
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  wait_for_steady_state = true

  # The task role needs its policy before the first remote write.
  depends_on = [aws_iam_role_policy.collector]
}
