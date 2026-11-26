# Lets GitHub Actions exchange its OIDC token for short-lived AWS credentials, so no AWS keys are
# stored in GitHub. Three roles:
#   plan  - read-only, for pull requests and main
#   apply - deploys and destroys the main stack, from main only
#   push  - pushes images to ECR, from main only

locals {
  github_oidc_host = "token.actions.githubusercontent.com"

  # The token's sub claim says where the workflow runs, with the owner and repository IDs next to
  # their names, e.g. repo:owner@123/name@456:ref:refs/heads/main. The IDs stop a deleted repository
  # recreated under the same name from assuming the roles.
  github_owner      = split("/", var.github_repository)[0]
  github_name       = split("/", var.github_repository)[1]
  github_repository = "repo:${local.github_owner}@${var.github_owner_id}/${local.github_name}@${var.github_repository_id}"

  github_subjects = {
    plan = [
      "${local.github_repository}:pull_request",
      "${local.github_repository}:ref:refs/heads/main",
    ]
    apply = [
      "${local.github_repository}:ref:refs/heads/main",
    ]
    push = [
      "${local.github_repository}:ref:refs/heads/main",
    ]
  }

  github_role_descriptions = {
    plan  = "run terraform plan on the main stack"
    apply = "run terraform apply and destroy on the main stack"
    push  = "push images to ECR"
  }

  # The roles that run Terraform on the main stack, and get its state.
  terraform_roles = toset(["plan", "apply"])
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://${local.github_oidc_host}"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "github_trust" {
  for_each = local.github_subjects

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:sub"
      values   = each.value
    }
  }
}

resource "aws_iam_role" "github" {
  for_each = local.github_subjects

  name                 = "${var.name_prefix}-github-${each.key}"
  description          = "Assumed by GitHub Actions in ${var.github_repository} to ${local.github_role_descriptions[each.key]}."
  assume_role_policy   = data.aws_iam_policy_document.github_trust[each.key].json
  max_session_duration = 3600
}

# State access. Both roles write lock files, because plan takes the lock too.

data "aws_iam_policy_document" "main_state" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [var.state_bucket_arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${var.ci_state_prefix}*"]
    }
  }

  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${var.state_bucket_arn}/${var.ci_state_prefix}*"]
  }
}

resource "aws_iam_role_policy" "main_state" {
  for_each = local.terraform_roles

  name   = "main-state"
  role   = aws_iam_role.github[each.key].id
  policy = data.aws_iam_policy_document.main_state.json
}

# Plan reads every resource type the main stack manages.
resource "aws_iam_role_policy_attachment" "plan_read_only" {
  role       = aws_iam_role.github["plan"].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Apply manages everything in the main stack, which includes IAM roles for ECS. A lab doesn't justify
# a hand-maintained least-privilege policy, so it gets AdministratorAccess, minus the resources
# below: CI can't change its own roles, the OIDC provider, the state bucket or the registry.
resource "aws_iam_role_policy_attachment" "apply_admin" {
  role       = aws_iam_role.github["apply"].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

data "aws_iam_policy_document" "protect_bootstrap" {
  statement {
    sid       = "DenyChangingCiRoles"
    effect    = "Deny"
    actions   = ["iam:*"]
    resources = concat(values(aws_iam_role.github)[*].arn, [aws_iam_openid_connect_provider.github.arn])
  }

  statement {
    sid    = "DenyChangingStateBucket"
    effect = "Deny"
    not_actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [var.state_bucket_arn, "${var.state_bucket_arn}/*"]
  }

  statement {
    sid       = "DenyBootstrapState"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = ["${var.state_bucket_arn}/${var.protected_state_prefix}*"]
  }

  # Reading and pulling stay allowed. Any region: replicas are covered too.
  statement {
    sid    = "DenyChangingRepositories"
    effect = "Deny"
    not_actions = [
      "ecr:Describe*",
      "ecr:List*",
      "ecr:Get*",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
    ]
    resources = [
      for arn in var.ecr_repository_arns :
      "arn:aws:ecr:*:${split(":", arn)[4]}:${split(":", arn)[5]}"
    ]
  }

  # Registry-wide settings the bootstrap owns; the main stack never needs to change them.
  statement {
    sid    = "DenyChangingRegistry"
    effect = "Deny"
    actions = [
      "ecr:PutReplicationConfiguration",
      "ecr:CreateRepositoryCreationTemplate",
      "ecr:UpdateRepositoryCreationTemplate",
      "ecr:DeleteRepositoryCreationTemplate",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "protect_bootstrap" {
  for_each = local.terraform_roles

  name   = "protect-bootstrap"
  role   = aws_iam_role.github[each.key].id
  policy = data.aws_iam_policy_document.protect_bootstrap.json
}

# Push: log in to ECR and push to the lab's repositories, nothing else. ECR copies the images to the
# replica region itself.
data "aws_iam_policy_document" "push" {
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = var.ecr_repository_arns
  }
}

resource "aws_iam_role_policy" "push" {
  name   = "ecr-push"
  role   = aws_iam_role.github["push"].id
  policy = data.aws_iam_policy_document.push.json
}
