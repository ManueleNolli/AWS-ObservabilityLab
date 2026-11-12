import logging

import pytest
from fastapi.testclient import TestClient
from prometheus_client import CollectorRegistry


def request_count(registry: CollectorRegistry, route: str, status: str) -> float:
    labels = {"method": "POST", "route": route, "status": status}
    return registry.get_sample_value("http_requests_total", labels) or 0


def test_requests_are_counted_by_route_and_status(
    client: TestClient, registry: CollectorRegistry
) -> None:
    client.post("/api/login")
    client.post("/api/login")
    client.post("/api/error")

    assert request_count(registry, "/api/login", "200") == 2
    assert request_count(registry, "/api/error", "500") == 1


def test_latency_is_observed(client: TestClient, registry: CollectorRegistry) -> None:
    client.post("/api/checkout")

    labels = {"method": "POST", "route": "/api/checkout"}
    assert registry.get_sample_value("http_request_duration_seconds_count", labels) == 1
    assert registry.get_sample_value("http_requests_in_progress", {"method": "POST"}) == 0


def test_unknown_paths_share_one_label(client: TestClient, registry: CollectorRegistry) -> None:
    client.post("/api/does-not-exist")
    client.post("/api/also-missing")

    assert request_count(registry, "unmatched", "404") == 2


def test_health_checks_are_not_recorded(client: TestClient, registry: CollectorRegistry) -> None:
    client.get("/api/health")

    labels = {"method": "GET", "route": "/api/health", "status": "200"}
    assert registry.get_sample_value("http_requests_total", labels) is None


def test_access_log_is_written(client: TestClient, caplog: pytest.LogCaptureFixture) -> None:
    with caplog.at_level(logging.INFO, logger="observability_lab.access"):
        client.post("/api/login")

    record = next(r for r in caplog.records if r.getMessage() == "request completed")
    assert record.route == "/api/login"
    assert record.status == 200


def test_api_docs_are_not_recorded(client: TestClient, registry: CollectorRegistry) -> None:
    client.get("/api/openapi.json")

    assert (
        registry.get_sample_value(
            "http_requests_total", {"method": "GET", "route": "unmatched", "status": "200"}
        )
        is None
    )
