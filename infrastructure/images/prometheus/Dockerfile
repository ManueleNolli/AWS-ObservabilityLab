# Prometheus with the AWS scrape config and the shared alert rules baked in.
# Built from the repository root: docker build -f infrastructure/images/prometheus/Dockerfile .
FROM prom/prometheus:v3.8.0
COPY infrastructure/images/prometheus/prometheus.yml /etc/prometheus/prometheus.yml
COPY observability/rules/*.yml /etc/prometheus/rules/
