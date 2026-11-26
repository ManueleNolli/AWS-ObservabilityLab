# Loki stores chunks and index in S3, the way Grafana Labs recommends running it. The bucket belongs
# to this stack, so Destroy deletes the logs too.

resource "aws_s3_bucket" "loki" {
  bucket_prefix = "${var.name}-loki-"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "loki" {
  bucket = aws_s3_bucket.loki.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Assumed by the Loki container to read and write its bucket.
resource "aws_iam_role" "loki" {
  name               = "${var.name}-loki"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
}

data "aws_iam_policy_document" "loki" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.loki.arn]
  }

  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.loki.arn}/*"]
  }
}

resource "aws_iam_role_policy" "loki" {
  name   = "s3"
  role   = aws_iam_role.loki.id
  policy = data.aws_iam_policy_document.loki.json
}

resource "aws_ecs_task_definition" "loki" {
  family                   = "${var.name}-loki"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.loki.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([{
    name         = "loki"
    image        = var.images.loki
    essential    = true
    portMappings = [{ containerPort = local.ports.loki, protocol = "tcp" }]

    # Read by loki.yml (-config.expand-env).
    environment = [
      { name = "LOKI_BUCKET", value = aws_s3_bucket.loki.id },
      { name = "LOKI_REGION", value = data.aws_region.current.region },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.this.name
        awslogs-region        = data.aws_region.current.region
        awslogs-stream-prefix = "loki"
      }
    }
  }])
}

resource "aws_ecs_service" "loki" {
  name            = "${var.name}-loki"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.loki.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  # A single instance with a local write-ahead log: stop the old task before starting the new one.
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.this.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.this["loki"].arn
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  wait_for_steady_state = true
}
