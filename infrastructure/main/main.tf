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

data "aws_caller_identity" "current" {}

module "network" {
  source = "../modules/network"

  name = var.project
}

# Shared by the backend and, later, the self-hosted monitoring services.
resource "aws_ecs_cluster" "this" {
  name = var.project

  # Billed per metric; the lab's own monitoring stack covers the same ground.
  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

module "backend" {
  source = "../modules/backend"

  name       = "${var.project}-backend"
  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids
  cluster_id = aws_ecs_cluster.this.id
  # ECR in var.region: the original in the bootstrap region, the replica anywhere else.
  image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.project}/backend:${var.image_tag}"
}
