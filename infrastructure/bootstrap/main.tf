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

# Each stack keeps its state under its own prefix; CI only gets access to main/.
module "github_oidc" {
  source = "../modules/github-oidc"

  name_prefix            = var.project
  github_repository      = var.github_repository
  state_bucket_arn       = module.state_bucket.arn
  ci_state_prefix        = "main/"
  protected_state_prefix = "bootstrap/"
}
