variable "region" {
  description = "Region of the state bucket. Independent of the region the main stack deploys to."
  type        = string
  default     = "eu-central-2"
}

variable "project" {
  description = "Prefix for resource names and value of the Project tag."
  type        = string
  default     = "observability-lab"
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the CI roles, as owner/name. Case-sensitive."
  type        = string
  default     = "ManueleNolli/AWS-ObservabilityLab"
}

variable "budget_limit_usd" {
  description = "Monthly cost budget for the account, in USD."
  type        = number
  default     = 20
}

variable "budget_email" {
  description = "Address for budget alerts. Not committed: copy terraform.tfvars.example to terraform.tfvars (gitignored), or set TF_VAR_budget_email."
  type        = string
}
