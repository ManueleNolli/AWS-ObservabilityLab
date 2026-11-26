# Container registry for the lab's images. Lives in the bootstrap stack so images survive a destroy of
# the main stack, and is replicated to a second region so a stack deployed there pulls locally.

locals {
  # Keeps the registry from growing forever: images are tagged with a git SHA and never overwritten.
  lifecycle_policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the last ${var.keep_images} images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.keep_images
      }
      action = { type = "expire" }
    }]
  })
}

data "aws_caller_identity" "current" {}

resource "aws_ecr_repository" "this" {
  for_each = var.repositories

  name                 = "${var.name_prefix}/${each.key}"
  image_tag_mutability = "IMMUTABLE"
  # Lets destroy.sh remove the bootstrap without deleting every image first.
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.this

  repository = each.value.name
  policy     = local.lifecycle_policy
}

# Account-wide: an ECR registry has a single replication configuration.
resource "aws_ecr_replication_configuration" "this" {
  replication_configuration {
    rule {
      destination {
        region      = var.replica_region
        registry_id = data.aws_caller_identity.current.account_id
      }

      repository_filter {
        filter      = var.name_prefix
        filter_type = "PREFIX_MATCH"
      }
    }
  }
}

# ECR creates the replica repositories itself, outside Terraform. The template, in the replica region,
# gives them the same settings as the repositories above.
resource "aws_ecr_repository_creation_template" "replica" {
  provider = aws.replica

  prefix               = var.name_prefix
  description          = "Repositories replicated from the ${var.name_prefix} registry."
  applied_for          = ["REPLICATION"]
  image_tag_mutability = "IMMUTABLE"
  lifecycle_policy     = local.lifecycle_policy

  encryption_configuration {
    encryption_type = "AES256"
  }
}
