# Frontend

A Vue 3 + TypeScript single-page app that generates traffic for the backend and shows what happened
from the browser's side. Each click becomes a real request, which the backend turns into metrics and
logs. There is no background traffic, so the dashboards only move when someone uses this page.

## What's on the page

| Section | Purpose |
| --- | --- |
| Action cards | One per endpoint (Login, Checkout, Search, Trigger error), with sent and failed counts |
| Random burst | 20 or 100 requests to random endpoints, started over about 3 s, to fill the dashboards quickly |
| Session stats | Requests sent, success rate, errors, and p95 latency as measured in the browser |
| Latency timeline | The last 60 requests as bars: height is latency, colour is status |
| Activity log | Every request, filterable, with a copyable request ID |
| Header | API health indicator, and an optional link to Grafana |

Browsers open at most **6 connections per host** over HTTP/1.1, which is what nginx speaks locally.
A 100-request burst is therefore queued in the browser: the backend never sees more than 6
requests in flight, and the latency measured here includes the time spent queued. Behind
CloudFront (HTTP/2) many requests share one connection, so that limit goes away.

The **request ID** links the frontend to the backend. The backend returns it in the
`X-Request-ID` header and writes it into its log line. Copy it here, then search for it in the
Grafana logs dashboard to find that exact request.

## Structure

```
src/
├── main.ts              Mounts the app
├── App.vue              Page layout: creates the session state, passes it to components
├── api/                 Talking to the backend
│   ├── endpoints.ts     The list of demo endpoints (method, path, label)
│   └── client.ts        fetch wrapper: times each request, reads X-Request-ID, never throws
├── composables/         State and behaviour, reusable across components
│   ├── useActivity.ts   Session state: sends requests, keeps the log, computes the stats, runs bursts
│   └── useApiHealth.ts  Polls /api/health every 10 s
├── lib/                 Plain TypeScript helpers, no Vue
│   ├── stats.ts         Status → outcome, percentile, formatting
│   └── random.ts        randomItem(), sleep()
├── components/          Display only: receive props, emit events
│   ├── AppHeader.vue  ActionCard.vue  BurstCard.vue  SessionStats.vue
│   ├── StatTile.vue  LatencyTimeline.vue  ActivityLog.vue  StatusBadge.vue
└── assets/main.css      Design tokens (colours, spacing) for light and dark mode
```

Dependencies point one way: `components` → `composables` → `api` / `lib`. Components contain
no request or stats logic, so that logic is tested without rendering anything. Tests live in
`__tests__/` folders next to the code they cover.

### What happens on a click

1. `ActionCard` emits `send`, and `App.vue` calls `run(endpoint)` from `useActivity`.
2. `client.ts` sends the request with `fetch` and measures how long it takes. If the network
   fails, the request is recorded with status `0` instead of throwing an error.
3. `useActivity` adds the result to the log (it keeps the last 200), and updates the counters
   and stats.
4. Vue re-renders every component that uses that state: the counts, tiles, timeline and log.

## Talking to the API

The app always calls relative paths (`/api/...`), so it never needs to know the backend's address:

| Where | Who serves `/` | Who forwards `/api/*` |
| --- | --- | --- |
| `npm run dev` | Vite dev server (:5173) | Vite proxy → `API_PROXY_TARGET` (default `http://localhost:8080`) |
| docker compose | nginx in the frontend container | nginx → `backend:8000` (`local/nginx/default.conf`) |
| AWS | CloudFront → S3 | CloudFront → ALB → Fargate |

## Configuration

| Variable | When | |
| --- | --- | --- |
| `VITE_GRAFANA_URL` | Build time | Shows an "Open Grafana" link in the header; hidden when empty |
| `API_PROXY_TARGET` | `npm run dev` only | Where the dev server forwards `/api` |

`VITE_*` variables are compiled into the bundle, so changing one requires a rebuild.

## Development

Requires Node 24.

```bash
npm ci                 # install dependencies
npm run dev            # http://localhost:5173 (start the docker compose stack first for the API)
npm test               # Vitest unit tests
npm run type-check     # vue-tsc
npm run lint           # ESLint
npm run format         # Prettier
npm run build          # type-check + production build into dist/
```

`dist/` is plain static files. Locally they're baked into an nginx image (see `Dockerfile`), and in
AWS they're synced to S3.
