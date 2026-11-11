** Work in progress **

# AWS-ObservabilityLab
A tiny web app on AWS Fargate that turns user clicks into metrics and logs, observed with Prometheus and Grafana. Self-hosted or AWS-managed, switchable with one Terraform variable.

## Repository layout

| Path | Contents |
| --- | --- |
| `backend/` | FastAPI service (Python, managed with [uv](https://docs.astral.sh/uv/)) |
| `frontend/` | Vue 3 + TypeScript single-page app, built with Vite into static files |
| `observability/` | Grafana dashboards and Prometheus alert rules, shared by every environment |
| `local/` | Config for the local Docker Compose stack only |

## Run locally

Requires Docker. No AWS account needed.

```bash
docker compose up --build
```

| Service | URL |
| --- | --- |
| App | http://localhost:8080 |
| Grafana | http://localhost:3000 (no login) |
| Prometheus | http://localhost:9090 |

Click the buttons in the app, then open the **Observability Lab** dashboards in Grafana.
If a port is taken, override it, e.g. `APP_PORT=8081 docker compose up`.

## Backend

| Endpoint | Behaviour |
| --- | --- |
| `POST /api/login` | Fails with 401 20% of the time |
| `POST /api/checkout` | Takes 0.5–2.5 s, fails with 500 10% of the time |
| `GET /api/search?q=` | Fast |
| `POST /api/error` | Always raises, returns 500 |
| `GET /api/health` | Health check, excluded from metrics and logs |

Prometheus metrics are served on a separate port (`9100`), and logs are JSON lines on stdout.
Rates and latencies are configurable through `LAB_*` environment variables (see `backend/src/observability_lab/config.py`).

```bash
cd backend
uv sync
uv run pytest
uv run ruff check . && uv run ruff format --check .
```

## Frontend

```bash
cd frontend
npm ci
npm run dev        # http://localhost:5173, proxies /api to the compose stack on :8080
npm test
npm run type-check && npm run lint && npm run format:check
npm run build      # static files in dist/
```

Set `VITE_GRAFANA_URL` at build time to show an "Open Grafana" link in the header.

## Alert rules

Alert rules have their own unit tests:

```bash
docker run --rm -v "$PWD/observability:/obs" -w /obs/rules/tests --entrypoint promtool prom/prometheus:v3.8.0 test rules app-alerts.test.yml
```
