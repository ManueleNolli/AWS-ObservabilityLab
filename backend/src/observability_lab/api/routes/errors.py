from fastapi import APIRouter

from observability_lab.api import API_PREFIX

router = APIRouter(prefix=API_PREFIX, tags=["errors"])


class TriggeredError(RuntimeError):
    """Raised on purpose and deliberately left unhandled, to exercise the error path."""


@router.post("/error")
async def trigger_error() -> None:
    raise TriggeredError("Error triggered from the UI")
