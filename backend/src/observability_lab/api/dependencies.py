"""Request-scoped access to the services built at startup."""

from typing import Annotated

from fastapi import Depends, Request

from observability_lab.services import Services
from observability_lab.services.auth import AuthService
from observability_lab.services.shop import ShopService


def get_services(request: Request) -> Services:
    return request.app.state.services


def get_auth_service(request: Request) -> AuthService:
    return get_services(request).auth


def get_shop_service(request: Request) -> ShopService:
    return get_services(request).shop


AuthServiceDep = Annotated[AuthService, Depends(get_auth_service)]
ShopServiceDep = Annotated[ShopService, Depends(get_shop_service)]
