"""Records metrics and an access log line for every request.

It is also the error boundary: unhandled exceptions are logged once, with the
request ID, and turned into a plain 500 response.
"""

import logging
import time
import uuid

from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import JSONResponse, Response
from starlette.types import ASGIApp

from observability_lab.observability.logs import request_id_var
from observability_lab.observability.metrics import HttpMetrics

logger = logging.getLogger("observability_lab.access")

# Requests that match no route share one label value, keeping metric cardinality bounded.
UNMATCHED_ROUTE = "unmatched"


def matched_route(request: Request) -> str:
    """Return the route template (``/api/items/{id}``), never the raw path.

    The router stores the matched route in the request scope, so this is only
    meaningful once the request has been routed.
    """
    route = request.scope.get("route")
    return getattr(route, "path", UNMATCHED_ROUTE)


class ObservabilityMiddleware(BaseHTTPMiddleware):
    def __init__(
        self, app: ASGIApp, metrics: HttpMetrics, excluded_paths: frozenset[str] = frozenset()
    ) -> None:
        super().__init__(app)
        self._metrics = metrics
        self._excluded_paths = excluded_paths

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        if request.url.path in self._excluded_paths:
            return await call_next(request)

        method = request.method
        request_id = uuid.uuid4().hex
        token = request_id_var.set(request_id)
        in_progress = self._metrics.in_progress.labels(method)
        in_progress.inc()
        start = time.perf_counter()
        try:
            response = await self._call_safely(request, call_next)
            duration = time.perf_counter() - start
            self._record(
                method, matched_route(request), response.status_code, duration, request.url.path
            )
            response.headers["X-Request-ID"] = request_id
            return response
        finally:
            in_progress.dec()
            request_id_var.reset(token)

    @staticmethod
    async def _call_safely(request: Request, call_next: RequestResponseEndpoint) -> Response:
        try:
            return await call_next(request)
        except Exception:
            logger.exception("unhandled exception")
            return JSONResponse({"detail": "Internal Server Error"}, status_code=500)

    def _record(self, method: str, route: str, status: int, duration: float, path: str) -> None:
        self._metrics.requests.labels(method, route, str(status)).inc()
        self._metrics.duration.labels(method, route).observe(duration)
        logger.log(
            logging.ERROR if status >= 500 else logging.INFO,
            "request completed",
            extra={
                "method": method,
                "path": path,
                "route": route,
                "status": status,
                "duration_ms": round(duration * 1000, 2),
            },
        )
