provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.project
      Stack     = "main"
      ManagedBy = "terraform"
    }
  }
}

# Only for reading AWS's public list of service regions, which isn't published in opt-in regions
# such as Zurich.
provider "aws" {
  alias  = "global_infrastructure"
  region = "us-east-1"
}
