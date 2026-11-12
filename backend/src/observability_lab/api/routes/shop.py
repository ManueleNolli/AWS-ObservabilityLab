from fastapi import APIRouter

from observability_lab.api import API_PREFIX
from observability_lab.api.dependencies import ShopServiceDep
from observability_lab.api.schemas import CheckoutResponse, SearchResponse

router = APIRouter(prefix=API_PREFIX, tags=["shop"])


@router.post("/checkout")
async def checkout(shop: ShopServiceDep) -> CheckoutResponse:
    return CheckoutResponse(order_id=await shop.checkout())


@router.get("/search")
async def search(shop: ShopServiceDep, q: str = "") -> SearchResponse:
    return SearchResponse(query=q, results=await shop.search(q))
