# Grafana with the AWS data sources and the shared dashboards baked in.
# Built from the repository root: docker build -f infrastructure/images/grafana/Dockerfile .
FROM grafana/grafana:12.3.0
COPY infrastructure/images/grafana/provisioning /etc/grafana/provisioning
COPY observability/dashboards /var/lib/grafana/dashboards
