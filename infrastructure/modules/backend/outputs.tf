output "alb_arn" {
  description = "ARN of the internal ALB."
  value       = aws_lb.this.arn
}

output "alb_security_group_id" {
  description = "Security group of the ALB: add ingress rules to it for whatever reaches the ALB."
  value       = aws_security_group.alb.id
}
