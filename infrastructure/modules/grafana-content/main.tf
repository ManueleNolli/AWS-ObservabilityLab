# What lives inside the Amazon Managed Grafana workspace: the AMP and CloudWatch data sources, and the
# dashboards. Applied through the Grafana provider with the workspace's service account token.

locals {
  # The shared Overview dashboard picks its data source through a variable that lists data sources of
  # one type. In Grafana 12, AMP is its own plugin rather than the core Prometheus one, so that
  # variable lists the AMP plugin here; the panels and queries stay as they are.
  overview = jsondecode(file(var.overview_dashboard_file))
  overview_managed = merge(local.overview, {
    templating = merge(local.overview.templating, {
      # Through JSON strings, because the variables are objects of different shapes.
      list = [
        for v in local.overview.templating.list : jsondecode(
          v.type == "datasource" ? jsonencode(merge(v, { query = grafana_data_source.prometheus.type })) : jsonencode(v)
        )
      ]
    })
  })
}

resource "grafana_data_source" "prometheus" {
  type       = "grafana-amazonprometheus-datasource"
  name       = "Amazon Managed Prometheus"
  uid        = "prometheus"
  is_default = true
  # Without the trailing slash: Grafana appends /api/v1/….
  url = trimsuffix(var.prometheus_endpoint, "/")

  # Signed with the workspace's IAM role.
  json_data_encoded = jsonencode({
    httpMethod    = "POST"
    sigV4Auth     = true
    sigV4AuthType = "ec2_iam_role"
    sigV4Region   = var.region
    timeInterval  = "10s"
  })
}

resource "grafana_data_source" "cloudwatch" {
  type = "cloudwatch"
  name = "CloudWatch"
  uid  = "cloudwatch"

  json_data_encoded = jsonencode({
    authType      = "ec2_iam_role"
    defaultRegion = var.region
  })

  # Grafana makes the first data source it creates the default, whatever is_default says.
  depends_on = [grafana_data_source.prometheus]
}

resource "grafana_folder" "this" {
  title = "Observability Lab"
}

resource "grafana_dashboard" "overview" {
  folder      = grafana_folder.this.uid
  config_json = jsonencode(local.overview_managed)
  overwrite   = true
}

# The Loki logs dashboard rewritten for CloudWatch Logs Insights; the backend log group is filled in
# here because its ARN contains the account.
resource "grafana_dashboard" "logs" {
  folder = grafana_folder.this.uid
  config_json = replace(
    replace(file("${path.module}/dashboards/app-logs-cloudwatch.json"), "__BACKEND_LOG_GROUP_ARN__", var.backend_log_group_arn),
    "__BACKEND_LOG_GROUP__", var.backend_log_group_name,
  )
  overwrite = true
}

resource "grafana_organization_preferences" "this" {
  home_dashboard_uid = grafana_dashboard.overview.uid
}
