"""Maps service errors to HTTP responses. Anything else stays an unhandled 500."""

from collections.abc import Awaitable, Callable

from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse

from observability_lab.services.errors import (
    InvalidCredentialsError,
    PaymentProviderError,
    ServiceError,
)

STATUS_BY_ERROR: dict[type[ServiceError], int] = {
    InvalidCredentialsError: status.HTTP_401_UNAUTHORIZED,
    PaymentProviderError: status.HTTP_500_INTERNAL_SERVER_ERROR,
}


def register_error_handlers(app: FastAPI) -> None:
    for error_type, status_code in STATUS_BY_ERROR.items():
        app.add_exception_handler(error_type, _responder(status_code))


def _responder(status_code: int) -> Callable[[Request, Exception], Awaitable[JSONResponse]]:
    async def respond(_: Request, exc: Exception) -> JSONResponse:
        return JSONResponse({"detail": str(exc)}, status_code=status_code)

    return respond
