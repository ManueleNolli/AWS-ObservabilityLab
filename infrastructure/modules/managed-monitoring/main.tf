# Managed monitoring: an Amazon Managed Prometheus workspace that evaluates the shared alert rules,
# fed by an ADOT collector on Fargate. AMP's own scrapers only work for EKS, so the collector does
# what self-hosted Prometheus does: scrape the backend tasks it finds in Cloud Map.

data "aws_region" "current" {}

# AMP's rule evaluation and alerting errors, e.g. a rule that fails to parse.
resource "aws_cloudwatch_log_group" "prometheus" {
  name              = "/aws/prometheus/${var.name}"
  retention_in_days = 7
}

resource "aws_prometheus_workspace" "this" {
  alias = var.name

  logging_configuration {
    log_group_arn = "${aws_cloudwatch_log_group.prometheus.arn}:*"
  }
}

# The same rules self-hosted Prometheus bakes into its image.
resource "aws_prometheus_rule_group_namespace" "alerts" {
  name         = "app-alerts"
  workspace_id = aws_prometheus_workspace.this.id
  data         = file(var.alert_rules_file)
}
