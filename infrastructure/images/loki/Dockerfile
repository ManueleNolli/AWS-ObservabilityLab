# Single-binary Loki storing chunks and index in S3.
FROM grafana/loki:3.6.0
COPY loki.yml /etc/loki/loki.yml
CMD ["-config.file=/etc/loki/loki.yml", "-config.expand-env=true"]
