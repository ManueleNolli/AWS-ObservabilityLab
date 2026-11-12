from fastapi import APIRouter

from observability_lab.api import API_PREFIX
from observability_lab.api.dependencies import AuthServiceDep
from observability_lab.api.schemas import LoginResponse

router = APIRouter(prefix=API_PREFIX, tags=["auth"])


@router.post("/login")
async def login(auth: AuthServiceDep) -> LoginResponse:
    await auth.login()
    return LoginResponse()
