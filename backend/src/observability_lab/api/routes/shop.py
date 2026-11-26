from fastapi import APIRouter

from observability_lab.api import API_PREFIX
from observability_lab.api.dependencies import ServicesDep
from observability_lab.api.schemas import CheckoutResponse, SearchResponse

router = APIRouter(prefix=API_PREFIX, tags=["shop"])


@router.post("/checkout")
async def checkout(services: ServicesDep) -> CheckoutResponse:
    order_id = await services.shop.checkout()
    return CheckoutResponse(status="order_placed", order_id=order_id)


@router.get("/search")
async def search(services: ServicesDep, q: str = "") -> SearchResponse:
    results = await services.shop.search(q)
    return SearchResponse(query=q, results=results)
