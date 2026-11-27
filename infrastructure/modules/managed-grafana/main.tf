# Amazon Managed Grafana: a workspace you sign in to through IAM Identity Center, reading Amazon
# Managed Prometheus and CloudWatch with its own IAM role. The data sources and dashboards inside it
# are Grafana objects, provisioned by the grafana-content module with the service account token below.

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_iam_policy_document" "grafana_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["grafana.amazonaws.com"]
    }

    # Only workspaces of this account, so another account's Grafana can't borrow the role.
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "StringLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:grafana:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:/workspaces/*"]
    }
  }
}

# Assumed by the workspace for every data source query ("Workspace IAM Role" in Grafana).
resource "aws_iam_role" "workspace" {
  name               = "${var.name}-grafana"
  assume_role_policy = data.aws_iam_policy_document.grafana_trust.json
}

# CloudWatch metrics and Logs Insights, read-only.
resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.workspace.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonGrafanaCloudWatchAccess"
}

# Queries, and the rules and alerts view, on the one workspace.
data "aws_iam_policy_document" "prometheus" {
  statement {
    actions = [
      "aps:QueryMetrics",
      "aps:GetLabels",
      "aps:GetSeries",
      "aps:GetMetricMetadata",
      "aps:ListRules",
      "aps:ListAlerts",
    ]
    resources = [var.prometheus_workspace_arn]
  }
}

resource "aws_iam_role_policy" "prometheus" {
  name   = "prometheus-query"
  role   = aws_iam_role.workspace.id
  policy = data.aws_iam_policy_document.prometheus.json
}

resource "aws_grafana_workspace" "this" {
  name                     = var.name
  description              = "Dashboards for ${var.name}: Amazon Managed Prometheus and CloudWatch."
  grafana_version          = "12.4"
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  # Our own role above, instead of the service-managed one AMG would create.
  permission_type = "CUSTOMER_MANAGED"
  role_arn        = aws_iam_role.workspace.arn

  # Everything Grafana needs is provisioned: no plugin installs from the UI.
  configuration = jsonencode({
    plugins         = { pluginAdminEnabled = false }
    unifiedAlerting = { enabled = true }
  })

  depends_on = [aws_iam_role_policy_attachment.cloudwatch, aws_iam_role_policy.prometheus]
}

# The Identity Center user who gets the Admin role. The instance can live in another region than the
# workspace: AMG reaches it across regions.
data "aws_ssoadmin_instances" "this" {
  provider = aws.identity_center

  lifecycle {
    postcondition {
      condition     = length(self.identity_store_ids) == 1
      error_message = "No IAM Identity Center instance in ${self.region}: set identity_center_region (the IDENTITY_CENTER_REGION repository variable) to the region it lives in."
    }
  }
}

data "aws_identitystore_user" "admin" {
  provider = aws.identity_center

  identity_store_id = one(data.aws_ssoadmin_instances.this.identity_store_ids)

  alternate_identifier {
    unique_attribute {
      attribute_path  = "UserName"
      attribute_value = var.admin_user_name
    }
  }
}

resource "aws_grafana_role_association" "admin" {
  workspace_id = aws_grafana_workspace.this.id
  role         = "ADMIN"
  user_ids     = [data.aws_identitystore_user.admin.user_id]
}

# Used by Terraform's Grafana provider to create the data sources and dashboards.
resource "aws_grafana_workspace_service_account" "terraform" {
  workspace_id = aws_grafana_workspace.this.id
  name         = "terraform"
  grafana_role = "ADMIN"
}

# AMG's maximum lifetime: 30 days. The stack is destroyed long before that; one that lives longer
# needs this token replaced (README, "Managed Grafana").
resource "aws_grafana_workspace_service_account_token" "terraform" {
  workspace_id       = aws_grafana_workspace.this.id
  service_account_id = aws_grafana_workspace_service_account.terraform.service_account_id
  name               = "terraform"
  seconds_to_live    = 30 * 24 * 60 * 60
}
