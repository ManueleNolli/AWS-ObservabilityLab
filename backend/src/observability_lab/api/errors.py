"""Turns service errors into HTTP responses. Any other exception stays an unhandled 500."""

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


async def handle_service_error(_: Request, exc: Exception) -> JSONResponse:
    status_code = STATUS_BY_ERROR.get(type(exc), status.HTTP_500_INTERNAL_SERVER_ERROR)
    return JSONResponse({"detail": str(exc)}, status_code=status_code)


def register_error_handlers(app: FastAPI) -> None:
    app.add_exception_handler(ServiceError, handle_service_error)
