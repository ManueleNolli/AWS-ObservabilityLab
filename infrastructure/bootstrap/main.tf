provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.project
      Stack     = "bootstrap"
      ManagedBy = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

module "state_bucket" {
  source = "../modules/state-bucket"

  # The account ID makes the globally unique name predictable.
  name = "${var.project}-tfstate-${data.aws_caller_identity.current.account_id}"
}

# The CI roles trust the repository by its GitHub IDs too, so look them up from the public API.
data "http" "github_repository" {
  url             = "https://api.github.com/repos/${var.github_repository}"
  request_headers = { Accept = "application/vnd.github+json" }

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "GitHub returned ${self.status_code} for ${var.github_repository}: check github_repository."
    }
  }
}

locals {
  github_repository = jsondecode(data.http.github_repository.response_body)
}

# Each stack keeps its state under its own prefix; CI only gets access to main/.
module "github_oidc" {
  source = "../modules/github-oidc"

  name_prefix            = var.project
  github_repository      = var.github_repository
  github_owner_id        = local.github_repository.owner.id
  github_repository_id   = local.github_repository.id
  state_bucket_arn       = module.state_bucket.arn
  ci_state_prefix        = "main/"
  protected_state_prefix = "bootstrap/"
}

# Lives here, not in the main stack, so it keeps watching the account while the main stack is destroyed.
module "budget" {
  source = "../modules/budget"

  name      = "${var.project}-monthly"
  limit_usd = var.budget_limit_usd
  email     = var.budget_email
}
