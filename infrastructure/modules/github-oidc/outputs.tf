output "plan_role_arn" {
  description = "Role for terraform plan in GitHub Actions."
  value       = aws_iam_role.github["plan"].arn
}

output "apply_role_arn" {
  description = "Role for terraform apply and destroy in GitHub Actions."
  value       = aws_iam_role.github["apply"].arn
}

output "push_role_arn" {
  description = "Role for pushing images to ECR in GitHub Actions."
  value       = aws_iam_role.github["push"].arn
}
