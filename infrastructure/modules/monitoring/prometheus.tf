# Prometheus scrapes the backend tasks it finds in Cloud Map and evaluates the alert rules. Its data
# lives on the task's disk: lost when the task is replaced, and every Destroy wipes it anyway.

resource "aws_ecs_task_definition" "prometheus" {
  family                   = "${var.name}-prometheus"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([{
    name         = "prometheus"
    image        = var.images.prometheus
    essential    = true
    portMappings = [{ containerPort = local.ports.prometheus, protocol = "tcp" }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.this.name
        awslogs-region        = data.aws_region.current.region
        awslogs-stream-prefix = "prometheus"
      }
    }
  }])
}

resource "aws_ecs_service" "prometheus" {
  name            = "${var.name}-prometheus"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.prometheus.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  # A single instance with local data: stop the old task before starting the new one.
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.this.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.this["prometheus"].arn
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  wait_for_steady_state = true
}
