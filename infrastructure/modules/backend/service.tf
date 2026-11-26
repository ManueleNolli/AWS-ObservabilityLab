# The backend API on Fargate: ARM64 tasks in the private subnets, behind the internal ALB.

locals {
  port         = 8000
  metrics_port = 9100
  firelens     = var.log_router != null

  awslogs = {
    logDriver = "awslogs"
    options = tomap({
      awslogs-group         = aws_cloudwatch_log_group.this.name
      awslogs-region        = data.aws_region.current.region
      awslogs-stream-prefix = "backend"
    })
  }

  backend_container = merge({
    name      = "backend"
    image     = var.image
    essential = true

    portMappings = [
      { containerPort = local.port, protocol = "tcp" },
      { containerPort = local.metrics_port, protocol = "tcp" },
    ]

    environment = [{ name = "LAB_LOG_LEVEL", value = "INFO" }]

    # Same check as docker-compose.yml: a task that stops answering is replaced even before the ALB
    # notices.
    healthCheck = {
      command     = ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:${local.port}/api/health')"]
      interval    = 10
      timeout     = 3
      retries     = 3
      startPeriod = 10
    }

    # With a log router, stdout goes through FireLens; its outputs (Loki and CloudWatch) are in the
    # router image's config, so there are no options here.
    logConfiguration = local.firelens ? { logDriver = "awsfirelens", options = tomap({}) } : local.awslogs
    },
    # The router must be up before the backend writes its first line.
    local.firelens ? { dependsOn = [{ containerName = "log-router", condition = "START" }] } : {},
  )

  # FireLens: Fluent Bit next to the backend, receiving its stdout. Its own logs go to CloudWatch.
  log_router_container = local.firelens ? {
    name              = "log-router"
    image             = var.log_router.image
    essential         = true
    memoryReservation = 50

    firelensConfiguration = {
      type = "fluentbit"
      options = {
        config-file-type  = "file"
        config-file-value = "/fluent-bit/etc/outputs.conf"
      }
    }

    environment = [
      { name = "LOKI_HOST", value = var.log_router.loki_host },
      { name = "LOG_GROUP", value = aws_cloudwatch_log_group.this.name },
      { name = "AWS_REGION", value = data.aws_region.current.region },
    ]

    logConfiguration = merge(local.awslogs, {
      options = merge(local.awslogs.options, { awslogs-stream-prefix = "log-router" })
    })
  } : null
}

data "aws_region" "current" {}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.name}"
  retention_in_days = 7
}

# Used by ECS itself, before the container starts: pull the image, create the log stream.
data "aws_iam_policy_document" "ecs_tasks_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.name}-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = local.firelens ? aws_iam_role.task[0].arn : null

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  # The log router only exists with FireLens.
  container_definitions = jsonencode([
    for container in [local.log_router_container, local.backend_container] : container if container != null
  ])
}

# Assumed by the containers themselves: only Fluent Bit needs AWS access, to write the CloudWatch copy.
resource "aws_iam_role" "task" {
  count = local.firelens ? 1 : 0

  name               = "${var.name}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
}

data "aws_iam_policy_document" "task" {
  statement {
    actions   = ["logs:CreateLogStream", "logs:DescribeLogStreams", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.this.arn}:*"]
  }
}

resource "aws_iam_role_policy" "task" {
  count = local.firelens ? 1 : 0

  name   = "cloudwatch-logs"
  role   = aws_iam_role.task[0].id
  policy = data.aws_iam_policy_document.task.json
}

resource "aws_security_group" "tasks" {
  name_prefix = "${var.name}-"
  description = "Backend tasks"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "tasks_from_alb" {
  security_group_id            = aws_security_group.tasks.id
  description                  = "From the ALB"
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = local.port
  to_port                      = local.port
}

# Outbound to the VPC endpoints and, through the NAT gateways, anything else.
resource "aws_vpc_security_group_egress_rule" "tasks_all" {
  security_group_id = aws_security_group.tasks.id
  description       = "All outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_service_discovery_service" "this" {
  name = "backend"

  dns_config {
    namespace_id = var.service_discovery_namespace_id

    dns_records {
      type = "A"
      ttl  = 10
    }
  }
}

resource "aws_ecs_service" "this" {
  name            = var.name
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.this.arn
  launch_type     = "FARGATE"
  # ECS spreads Fargate tasks across the subnets' zones.
  desired_count = var.desired_count

  # Grace for the ALB health check while a new task starts.
  health_check_grace_period_seconds = 30

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.tasks.id]
    assign_public_ip = false
  }

  # Registers every task's IP as backend.<namespace>: that's how Prometheus finds them.
  service_registries {
    registry_arn = aws_service_discovery_service.this.arn
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "backend"
    container_port   = local.port
  }

  # A deployment whose tasks never get healthy is rolled back, and apply waits for the outcome, so a
  # broken image fails Deploy instead of crash-looping behind a green run.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  wait_for_steady_state = true

  # The target group can only receive targets once a listener attaches it to the ALB.
  depends_on = [aws_lb_listener.http]
}
