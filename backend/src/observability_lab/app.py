"""Application factory: wires settings, services, instrumentation and routes together."""

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from prometheus_client import REGISTRY, CollectorRegistry

from observability_lab.api import API_PREFIX
from observability_lab.api.errors import register_error_handlers
from observability_lab.api.routes import HEALTH_PATH, ROUTERS
from observability_lab.config import Settings
from observability_lab.observability.metrics import HttpMetrics, start_metrics_server
from observability_lab.observability.middleware import ObservabilityMiddleware
from observability_lab.services import Services
from observability_lab.services.auth import AuthService
from observability_lab.services.shop import ShopService
from observability_lab.services.simulator import Simulator

DOCS_PATH = f"{API_PREFIX}/docs"
OPENAPI_PATH = f"{API_PREFIX}/openapi.json"


def build_services(settings: Settings, simulator: Simulator) -> Services:
    return Services(
        auth=AuthService(
            simulator=simulator,
            failure_rate=settings.login_failure_rate,
            max_latency_s=settings.fast_latency_max_s,
        ),
        shop=ShopService(
            simulator=simulator,
            checkout_error_rate=settings.checkout_error_rate,
            checkout_min_latency_s=settings.checkout_latency_min_s,
            checkout_max_latency_s=settings.checkout_latency_max_s,
            search_max_latency_s=settings.fast_latency_max_s,
        ),
    )


def create_app(
    settings: Settings | None = None,
    registry: CollectorRegistry = REGISTRY,
    simulator: Simulator | None = None,
) -> FastAPI:
    settings = settings or Settings()

    @asynccontextmanager
    async def lifespan(_: FastAPI) -> AsyncIterator[None]:
        shutdown_metrics_server = start_metrics_server(settings.metrics_port, registry)
        try:
            yield
        finally:
            shutdown_metrics_server()

    app = FastAPI(
        title="Observability Lab",
        lifespan=lifespan,
        docs_url=DOCS_PATH,
        openapi_url=OPENAPI_PATH,
        redoc_url=None,
    )
    app.state.services = build_services(settings, simulator or Simulator())
    app.add_middleware(
        ObservabilityMiddleware,
        metrics=HttpMetrics(registry),
        # Only user-generated traffic is observed: no health checks, no API docs.
        excluded_paths=frozenset({HEALTH_PATH, DOCS_PATH, OPENAPI_PATH}),
    )
    register_error_handlers(app)
    for router in ROUTERS:
        app.include_router(router)
    return app
