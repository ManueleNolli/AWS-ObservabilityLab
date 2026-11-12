"""JSON bodies returned by the API. FastAPI validates responses against them and documents them."""

from pydantic import BaseModel


class StatusResponse(BaseModel):
    status: str


class CheckoutResponse(BaseModel):
    status: str
    order_id: str


class SearchResponse(BaseModel):
    query: str
    results: list[str]
