variable "name_prefix" {
  description = "Prefix for the role names."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the roles, as owner/name. Case-sensitive."
  type        = string
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
