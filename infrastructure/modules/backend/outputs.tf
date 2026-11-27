output "alb_arn" {
  description = "ARN of the internal ALB."
  value       = aws_lb.this.arn
}

output "alb_security_group_id" {
  description = "Security group of the ALB: add ingress rules to it for whatever reaches the ALB."
  value       = aws_security_group.alb.id
}

output "alb_dns_name" {
  description = "DNS name of the internal ALB."
  value       = aws_lb.this.dns_name
}

output "alb_listener_arn" {
  description = "HTTP listener of the ALB: add listener rules to it to route paths elsewhere."
  value       = aws_lb_listener.http.arn
}

output "tasks_security_group_id" {
  description = "Security group of the backend tasks."
  value       = aws_security_group.tasks.id
}

output "metrics_port" {
  description = "Port the tasks serve Prometheus metrics on."
  value       = local.metrics_port
}

output "log_group_name" {
  description = "CloudWatch log group of the backend containers."
  value       = aws_cloudwatch_log_group.this.name
}

output "log_group_arn" {
  description = "ARN of the backend's log group, without the trailing :*."
  value       = aws_cloudwatch_log_group.this.arn
}
