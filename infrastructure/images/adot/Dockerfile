# Managed-mode metrics collector: AWS Distro for OpenTelemetry plus our scrape and remote-write config.
FROM public.ecr.aws/aws-observability/aws-otel-collector:v0.51.0
COPY config.yaml /etc/otel/config.yaml
CMD ["--config=/etc/otel/config.yaml"]
