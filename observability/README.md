# Observability

The monitoring config that every environment shares: Grafana dashboards and Prometheus alert
rules, stored as code. The same files are loaded locally (docker compose), in `self_hosted`
mode and in `managed` mode, so a dashboard looks the same everywhere.

Config for a single environment, such as data source URLs, scrape targets and Loki, lives
elsewhere: `local/` for docker compose, and later the Terraform modules for AWS.

```
observability/
├── dashboards/
│   ├── app-overview.json      Metrics dashboard (Prometheus)
│   └── app-logs-loki.json     Logs dashboard (Loki)
└── rules/
    ├── app-alerts.yml         Prometheus alert rules
    └── tests/
        └── app-alerts.test.yml  Unit tests for the rules
```

## Dashboards

Each file is a Grafana dashboard exported as JSON. Grafana loads them at startup, so nobody
has to create them by hand.

### Overview: `app-overview.json`

Uses the **RED method**: Rate, Errors and Duration, the three numbers that summarise a request-driven
service.

| Panel | Shows | Built from |
| --- | --- | --- |
| Request rate | Requests per second | `rate(http_requests_total)` |
| Error ratio | Share of 5xx responses | 5xx rate ÷ total rate |
| p95 latency | 95% of requests were faster than this | `histogram_quantile(0.95, …_bucket)` |
| In flight | Requests being handled right now | `http_requests_in_progress` |
| Requests by route / by status | Traffic split by endpoint and status code | `sum by (route)` / `sum by (status)` |
| Latency percentiles | p50, p95 and p99 over time | `histogram_quantile` |
| p95 latency by route | Which endpoint is slow (hint: checkout) | `sum by (le, route)` |
| Error ratio by route | 4xx and 5xx share per endpoint | `sum by (route)` |

The variables at the top of the dashboard:
- **`datasource`** lets you pick which Prometheus to query. The panels don't hard-code a data
  source, so the same file works with the local Prometheus and with Amazon Managed Prometheus.
- **`route`** filters every panel to one or more endpoints.

### Logs: `app-logs-loki.json`

| Panel | Shows |
| --- | --- |
| Log volume by level | Log lines per level (info, warning, error) over time |
| Warnings and errors | Only problem lines, including tracebacks |
| All backend logs | Everything, newest first |

The **Search** box filters both log panels. Paste a request ID copied from the frontend to find
that exact request.

This dashboard is Loki-only: it works locally and in `self_hosted` mode. In `managed` mode logs go
to CloudWatch, which uses a different query language, so a separate CloudWatch dashboard will be
added in that step.

## Alert rules: `rules/app-alerts.yml`

Prometheus evaluates these continuously. An alert is first **pending** while its condition is true,
and becomes **firing** once it has stayed true for the `for:` duration.

| Alert | Fires when | Try it |
| --- | --- | --- |
| `BackendDown` | Prometheus can't scrape the backend for 1 min | `docker compose stop backend` |
| `HighErrorRate` | More than 5% of requests return 5xx | Click "Trigger error" a few times |
| `CheckoutSlow` | Checkout p95 latency is above 2 s | Send many checkouts (latency goes up to 2.5 s) |
| `LoginFailureSpike` | More than 30% of logins are rejected | Many logins; 20% fail by default, so it needs bad luck |

The thresholds are deliberately low, so a few clicks can trigger them. Locally, you can watch them
at http://localhost:9090/alerts. Nothing sends notifications yet: there is no Alertmanager.

Every rule filters on `job="backend"`, the scrape job name. Each environment has to use that
same job name for the rules to match.

### Rule tests: `rules/tests/app-alerts.test.yml`

`promtool` feeds made-up time series into the rules and checks which alerts fire. For example,
"10% errors for 8 minutes → `HighErrorRate` fires" and "healthy traffic → nothing fires". Run them
from the repository root:

```bash
docker run --rm -v "$PWD/observability:/obs" -w /obs/rules/tests \
  --entrypoint promtool prom/prometheus:v3.8.0 test rules app-alerts.test.yml
```

The tests live in their own folder because Prometheus loads every `*.yml` file in `rules/`, and a
test file there would break that.

## How each environment loads these files

| Environment | Dashboards | Rules |
| --- | --- | --- |
| docker compose | Mounted into Grafana, which loads them through `local/grafana/provisioning/dashboards/` | Mounted into Prometheus as `/etc/prometheus/rules/` |
| `self_hosted` (AWS) | Same Grafana provisioning, on ECS | Same Prometheus, on ECS |
| `managed` (AWS) | Uploaded to Amazon Managed Grafana by Terraform | Uploaded to Amazon Managed Prometheus as a rule group |

## Changing a dashboard

Provisioned dashboards can't be saved from the Grafana UI. To change one:
1. Edit the dashboard in Grafana. You can change it on screen, you just can't save it.
2. Use **Export → Export as JSON**, and replace the file in `dashboards/`.
3. Keep the `uid` the same, so links to the dashboard keep working. Keep `${datasource}` as each
   panel's data source, so the dashboard stays portable between environments.
4. Grafana re-reads the folder every 10 seconds, so refresh the page to see the result.

When you change an alert rule, update or add a test in `rules/tests/` and run `promtool`.
