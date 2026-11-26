from fastapi import APIRouter

from observability_lab.api import API_PREFIX
from observability_lab.api.dependencies import ServicesDep
from observability_lab.api.schemas import StatusResponse

router = APIRouter(prefix=API_PREFIX, tags=["auth"])


@router.post("/login")
async def login(services: ServicesDep) -> StatusResponse:
    await services.auth.login()
    return StatusResponse(status="logged_in")
