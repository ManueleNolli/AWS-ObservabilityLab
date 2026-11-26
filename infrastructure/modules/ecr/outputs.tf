output "repository_prefix" {
  description = "Registry URL plus name prefix: append /<name> for a repository's URL."
  value       = "${split("/", values(aws_ecr_repository.this)[0].repository_url)[0]}/${var.name_prefix}"
}

output "repository_arns" {
  description = "ARNs of the repositories in the source region."
  value       = values(aws_ecr_repository.this)[*].arn
}
