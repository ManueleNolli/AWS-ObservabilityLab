output "state_bucket" {
  description = "Bucket for the backend \"s3\" block of both stacks."
  value       = module.state_bucket.name
}

output "state_region" {
  description = "Region of the state bucket."
  value       = var.region
}

output "plan_role_arn" {
  description = "Role for terraform plan in GitHub Actions."
  value       = module.github_oidc.plan_role_arn
}

output "apply_role_arn" {
  description = "Role for terraform apply and destroy in GitHub Actions."
  value       = module.github_oidc.apply_role_arn
}

output "push_role_arn" {
  description = "Role for pushing images to ECR in GitHub Actions."
  value       = module.github_oidc.push_role_arn
}

output "ecr_repository_prefix" {
  description = "Registry URL plus name prefix: append /<name> for a repository's URL."
  value       = module.ecr.repository_prefix
}
