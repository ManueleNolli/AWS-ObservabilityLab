"""Prometheus HTTP metrics and the standalone ``/metrics`` server."""

from collections.abc import Callable

from prometheus_client import CollectorRegistry, Counter, Gauge, Histogram, start_http_server

LATENCY_BUCKETS_S = (0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 1.5, 2.0, 3.0, 5.0, 10.0)


class HttpMetrics:
    def __init__(self, registry: CollectorRegistry) -> None:
        self.requests = Counter(
            "http_requests",
            "HTTP requests handled, by route and status code.",
            ["method", "route", "status"],
            registry=registry,
        )
        self.duration = Histogram(
            "http_request_duration_seconds",
            "HTTP request latency.",
            ["method", "route"],
            buckets=LATENCY_BUCKETS_S,
            registry=registry,
        )
        self.in_progress = Gauge(
            "http_requests_in_progress",
            "HTTP requests currently being handled.",
            # The route is only known once the request has been routed.
            ["method"],
            registry=registry,
        )


def start_metrics_server(port: int, registry: CollectorRegistry) -> Callable[[], None]:
    """Expose ``registry`` on ``port`` in a background thread; return a shutdown function."""
    server, thread = start_http_server(port, registry=registry)

    def shutdown() -> None:
        server.shutdown()
        server.server_close()
        thread.join()

    return shutdown
