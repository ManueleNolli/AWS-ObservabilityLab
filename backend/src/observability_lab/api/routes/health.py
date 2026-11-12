from fastapi import APIRouter

from observability_lab.api import API_PREFIX
from observability_lab.api.schemas import HealthResponse

PATH = "/health"

router = APIRouter(prefix=API_PREFIX, tags=["health"])


@router.get(PATH)
async def health() -> HealthResponse:
    return HealthResponse()
