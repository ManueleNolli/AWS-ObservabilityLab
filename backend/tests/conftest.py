import random
from collections.abc import Callable, Iterator

import pytest
from fastapi.testclient import TestClient
from prometheus_client import CollectorRegistry

from observability_lab.app import create_app
from observability_lab.config import Settings
from observability_lab.services.simulator import Simulator

ClientFactory = Callable[..., TestClient]


@pytest.fixture
def registry() -> CollectorRegistry:
    return CollectorRegistry()


@pytest.fixture
def make_client(registry: CollectorRegistry) -> Iterator[ClientFactory]:
    """Build a client with no latency, no random failures, and any overrides applied."""
    clients: list[TestClient] = []

    def factory(**overrides: object) -> TestClient:
        defaults: dict[str, object] = {
            "metrics_port": 0,  # any free port
            "login_failure_rate": 0,
            "checkout_error_rate": 0,
            "checkout_latency_min_s": 0,
            "checkout_latency_max_s": 0,
            "fast_latency_max_s": 0,
        }
        settings = Settings(**(defaults | overrides))
        app = create_app(settings, registry, Simulator(random.Random(0)))
        client = TestClient(app, raise_server_exceptions=False)
        client.__enter__()
        clients.append(client)
        return client

    yield factory
    for client in clients:
        client.__exit__(None, None, None)


@pytest.fixture
def client(make_client: ClientFactory) -> TestClient:
    return make_client()


@pytest.fixture
def anyio_backend() -> str:
    return "asyncio"
