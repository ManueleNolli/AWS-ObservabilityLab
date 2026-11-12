** Work in progress **

# AWS-ObservabilityLab
A tiny web app on AWS Fargate that turns user clicks into metrics and logs, observed with Prometheus and Grafana. Self-hosted or AWS-managed, switchable with one Terraform variable.

## How it fits together

```
 browser ─► frontend (Vue, nginx) ──/api──► backend (FastAPI)
                                              │                 │
                                       metrics :9100     JSON logs (stdout)
                                              │                 │
                                              ▼                 ▼
                                     Prometheus (pulls)   Alloy ──► Loki
                                              │                 │
                                              └──► Grafana ◄────┘
                                              dashboards + alerts
```

Metrics answer "how many, how fast, how many errors". Logs answer "what exactly happened to this
request". The request ID ties the two together: the frontend shows it, the backend logs it.

## What each component is, and why it's here

### The app

| Component | What it is | Why |
| --- | --- | --- |
| **FastAPI** | Python web framework, built on **Starlette** | Small, typed, async; serves the demo endpoints |
| **uvicorn** | The server that runs the FastAPI app | Standard production server for async Python apps |
| **prometheus_client** | Python library for defining metrics and serving them as text | The official way to expose Prometheus metrics |
| **uv** | Python package and project manager | Fast, with a lockfile for reproducible installs |
| **Vue 3 + TypeScript** | Frontend framework | Reactive UI for the buttons, stats and log, with type checking |
| **Vite** | Frontend build tool and dev server | Fast dev server; builds plain static files for S3 |
| **nginx** | Web server and reverse proxy | Locally, plays CloudFront's role: serves the static files and forwards `/api` to the backend |

### Observability

| Component | What it is | Why |
| --- | --- | --- |
| **Prometheus** | Time-series database that **pulls** metrics: every 10 s it fetches `backend:9100/metrics` | Stores metric history and evaluates the alert rules |
| **Loki** | Log database from Grafana Labs | Stores the backend's JSON logs; searchable by labels and text, like Prometheus for logs |
| **Alloy** | Grafana Labs' collector agent, the successor to Promtail | Reads the backend container's stdout through the Docker socket, labels each line (`service`, `level`) and pushes it to Loki. The app only prints logs and doesn't know Loki exists |
| **Grafana** | Visualisation tool; stores no data itself | Queries Prometheus and Loki and draws the dashboards; the same dashboards work in every environment |

### AWS (coming in the next steps)

| Component | Why |
| --- | --- |
| **CloudFront** | Single public entry point: `/` → S3, `/api/*` → ALB |
| **S3** | Hosts the built frontend files |
| **ALB** | Load balancer in front of the backend; only accepts traffic from CloudFront |
| **ECS Fargate** | Runs the backend container without managing servers |
| **Amazon Managed Prometheus / Grafana, ADOT** | `managed` mode: AWS runs the monitoring instead of us |
| **Terraform** | All infrastructure as code; `monitoring_mode` switches `self_hosted` and `managed` |

## Repository layout

| Path | Contents | Docs |
| --- | --- | --- |
| `backend/` | FastAPI service | [backend/README.md](backend/README.md) |
| `frontend/` | Vue single-page app | [frontend/README.md](frontend/README.md) |
| `observability/` | Grafana dashboards and Prometheus alert rules, shared by every environment | [observability/README.md](observability/README.md) |
| `local/` | Config for the local Docker Compose stack only (nginx, Prometheus, Loki, Alloy, Grafana provisioning) | |

## Run locally

Requires Docker. No AWS account needed.

```bash
docker compose up --build
```

| Service | URL | What to look at |
| --- | --- | --- |
| App | http://localhost:8080 | Click the buttons, or fire a burst of 20 or 100 requests |
| Grafana | http://localhost:3000 (no login) | Dashboards → Observability Lab → **Overview** (metrics, alerts) and **Logs** |
| Prometheus | http://localhost:9090 | Raw metrics queries; **Alerts** tab shows every rule's state |

**Logs** are in Grafana: open the **Observability Lab / Logs** dashboard, or go to **Explore**,
pick **Loki** and run `{service="backend"}`. To follow a single request, paste its request ID from
the app into the dashboard's Search box.

If a port is taken, override it, e.g. `APP_PORT=8081 docker compose up`.

`docker compose down` stops everything; add `-v` to also delete the stored metrics and dashboards
state.
