# Internal ALB in the private subnets, in front of the backend tasks. Nothing outside the VPC reaches
# it: CloudFront will, through a VPC origin.

resource "aws_security_group" "alb" {
  name_prefix = "${var.name}-alb-"
  description = "Backend ALB"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

# No ingress rule here: whatever sits in front of the ALB adds one, using the alb_security_group_id
# output.

resource "aws_vpc_security_group_egress_rule" "alb_to_tasks" {
  security_group_id            = aws_security_group.alb.id
  description                  = "To the backend tasks"
  referenced_security_group_id = aws_security_group.tasks.id
  ip_protocol                  = "tcp"
  from_port                    = local.port
  to_port                      = local.port
}

resource "aws_lb" "this" {
  name               = var.name
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids

  drop_invalid_header_fields = true
}

resource "aws_lb_target_group" "this" {
  name        = var.name
  vpc_id      = var.vpc_id
  target_type = "ip"
  protocol    = "HTTP"
  port        = local.port

  # Default is 300s; the API holds no long requests, so deployments don't need to wait that long.
  deregistration_delay = 30

  health_check {
    path                = "/api/health"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

# Plain HTTP: without a domain there's no certificate for the ALB, and the traffic from CloudFront
# never leaves AWS's network.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
