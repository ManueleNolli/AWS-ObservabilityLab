# Backend

A FastAPI service whose only job is to produce interesting telemetry. Each endpoint simulates a
behaviour (failures, latency), and every request produces Prometheus metrics and a JSON log
line. There is no database, so the service is stateless.

## Endpoints

| Endpoint | Behaviour |
| --- | --- |
| `POST /api/login` | 401 for 20% of attempts |
| `POST /api/checkout` | Takes 0.5–2.5 s, and fails with 500 for 10% of orders |
| `GET /api/search?q=` | Fast, always succeeds |
| `POST /api/error` | Raises an unhandled exception, so always 500 |
| `GET /api/health` | Health check for the load balancer |
| `GET /api/docs` | Interactive API docs |

Prometheus metrics are served on a separate port, `:9100/metrics`, so they can stay private inside
the VPC. Health checks and docs are left out of metrics and logs.

## Structure

```
src/observability_lab/
├── __main__.py        Entry point: configures logging, starts uvicorn
├── app.py             Builds the app: creates the services, adds middleware, registers routes
├── config.py          Settings, read from LAB_* environment variables
├── api/               HTTP layer
│   ├── routes/        One router per area: health, auth, shop, errors
│   ├── schemas.py     Response bodies
│   ├── dependencies.py  Hands the services to route handlers (ServicesDep)
│   └── errors.py      Maps service errors to HTTP status codes
├── services/          Business behaviour, with no HTTP code
│   ├── auth.py        login()
│   ├── shop.py        checkout(), search()
│   ├── simulator.py   Random latency and failures
│   └── errors.py      Errors the services raise
└── observability/     Telemetry, applied to every request
    ├── middleware.py  Records metrics, writes the access log, adds X-Request-ID
    ├── metrics.py     Prometheus metrics and the /metrics server
    └── logs.py        JSON log formatter
```

Dependencies point one way: `api` → `services`, and `observability` wraps both from the outside.
Services don't import FastAPI, so they can be tested without HTTP.

### What happens on a request

1. `ObservabilityMiddleware` assigns a request ID and starts a timer.
2. The route handler calls a service, for example `services.auth.login()`.
3. If the service raises a `ServiceError`, `api/errors.py` turns it into a 401 or 500. Any other
   exception is caught by the middleware, logged with its traceback, and returned as a 500.
4. The middleware records the metrics and writes one JSON log line, which includes the request ID.
   The frontend shows that ID, so you can find the matching log line in Grafana.

## Telemetry

| Metric | Type | Labels |
| --- | --- | --- |
| `http_requests_total` | Counter | `method`, `route`, `status` |
| `http_request_duration_seconds` | Histogram | `method`, `route` |
| `http_requests_in_progress` | Gauge | `method` |

`route` is the route template, such as `/api/login`, never the raw URL. All unknown paths share the
label value `unmatched`, which keeps the number of metric series bounded.

## Configuration

| Variable | Default | |
| --- | --- | --- |
| `LAB_PORT` | `8000` | API port |
| `LAB_METRICS_PORT` | `9100` | Metrics port |
| `LAB_LOG_LEVEL` | `INFO` | |
| `LAB_LOGIN_FAILURE_RATE` | `0.2` | Share of logins rejected |
| `LAB_CHECKOUT_ERROR_RATE` | `0.1` | Share of checkouts that fail |
| `LAB_CHECKOUT_LATENCY_MIN_S` / `_MAX_S` | `0.5` / `2.5` | Checkout latency range |
| `LAB_FAST_LATENCY_MAX_S` | `0.15` | Maximum latency of login and search |

## Development

Requires [uv](https://docs.astral.sh/uv/).

```bash
uv sync                                  # install dependencies
uv run python -m observability_lab       # run on :8000, metrics on :9100
uv run pytest                            # tests, laid out like src/
uv run ruff check . && uv run ruff format --check .
```
