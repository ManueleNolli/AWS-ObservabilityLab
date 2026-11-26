# Fails the plan, instead of half an apply, when managed monitoring isn't available in var.region.
# Nothing reads it: the postcondition is the point.
# tflint-ignore: terraform_unused_declarations
data "aws_ssm_parameters_by_path" "managed_monitoring_regions" {
  for_each = var.monitoring_mode == "managed" ? toset(["grafana", "aps"]) : toset([])
  provider = aws.global_infrastructure

  path = "/aws/service/global-infrastructure/services/${each.key}/regions"

  lifecycle {
    postcondition {
      condition     = contains(self.values, var.region)
      error_message = "monitoring_mode = \"managed\" needs ${each.key == "aps" ? "Amazon Managed Prometheus" : "Amazon Managed Grafana"}, which isn't available in ${var.region}. Supported regions: ${join(", ", sort(nonsensitive(self.values)))}."
    }
  }
}
