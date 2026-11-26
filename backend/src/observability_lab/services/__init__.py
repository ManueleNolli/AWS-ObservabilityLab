"""Behaviour of the demo endpoints, independent of HTTP."""

from dataclasses import dataclass

from observability_lab.services.auth import AuthService
from observability_lab.services.shop import ShopService


@dataclass(frozen=True)
class Services:
    auth: AuthService
    shop: ShopService
