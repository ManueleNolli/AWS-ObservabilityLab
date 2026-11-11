"""Application factory."""

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from prometheus_client import REGISTRY, CollectorRegistry

from observability_lab.config import Settings
from observability_lab.metrics import HttpMetrics, start_metrics_server
from observability_lab.middleware import ObservabilityMiddleware
from observability_lab.routes import HEALTH_ROUTE, router
from observability_lab.simulation import Simulator


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
        docs_url="/api/docs",
        openapi_url="/api/openapi.json",
        redoc_url=None,
    )
    app.state.settings = settings
    app.state.simulator = simulator or Simulator()
    app.add_middleware(
        ObservabilityMiddleware,
        metrics=HttpMetrics(registry),
        # Load balancer health checks would drown out the user-generated traffic.
        excluded_routes=frozenset({HEALTH_ROUTE}),
    )
    app.include_router(router)
    return app
