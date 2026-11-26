variable "name_prefix" {
  description = "Prefix for the role names."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the roles, as owner/name. Case-sensitive."
  type        = string
}

variable "github_owner_id" {
  description = "Numeric ID of the repository owner on GitHub."
  type        = number
}

variable "github_repository_id" {
  description = "Numeric ID of the repository on GitHub."
  type        = number
}

variable "state_bucket_arn" {
  description = "ARN of the Terraform state bucket."
  type        = string
}

variable "ci_state_prefix" {
  description = "State key prefix the roles may read and write, with a trailing slash."
  type        = string
}

variable "protected_state_prefix" {
  description = "State key prefix the roles may not touch at all, with a trailing slash."
  type        = string
}

variable "ecr_repository_arns" {
  description = "ECR repositories the push role pushes to, and the other roles may not change."
  type        = list(string)
}
