terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
      # The region of the IAM Identity Center instance, for looking up the admin user.
      configuration_aliases = [aws.identity_center]
    }
  }
}
