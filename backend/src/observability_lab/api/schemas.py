"""Response bodies of the public API."""

from typing import Literal

from pydantic import BaseModel


class HealthResponse(BaseModel):
    status: Literal["ok"] = "ok"


class LoginResponse(BaseModel):
    status: Literal["logged_in"] = "logged_in"


class CheckoutResponse(BaseModel):
    status: Literal["order_placed"] = "order_placed"
    order_id: str


class SearchResponse(BaseModel):
    query: str
    results: list[str]
