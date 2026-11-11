"""Demo endpoints, one per frontend button."""

import logging
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, status

from observability_lab.config import Settings
from observability_lab.simulation import Simulator

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api")

HEALTH_ROUTE = "/api/health"


def get_settings(request: Request) -> Settings:
    return request.app.state.settings


def get_simulator(request: Request) -> Simulator:
    return request.app.state.simulator


SettingsDep = Annotated[Settings, Depends(get_settings)]
SimulatorDep = Annotated[Simulator, Depends(get_simulator)]


class TriggeredError(RuntimeError):
    """Raised on purpose by the "Trigger error" button."""


@router.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@router.post("/login")
async def login(settings: SettingsDep, simulator: SimulatorDep) -> dict[str, str]:
    await simulator.delay(0, settings.fast_latency_max_s)
    if simulator.fails(settings.login_failure_rate):
        logger.warning("login rejected", extra={"reason": "invalid_credentials"})
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid credentials")
    return {"status": "logged_in"}


@router.post("/checkout")
async def checkout(settings: SettingsDep, simulator: SimulatorDep) -> dict[str, str]:
    await simulator.delay(settings.checkout_latency_min_s, settings.checkout_latency_max_s)
    if simulator.fails(settings.checkout_error_rate):
        logger.error("checkout failed", extra={"reason": "payment_provider_unavailable"})
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, "Payment provider unavailable")
    return {"status": "order_placed"}


@router.get("/search")
async def search(settings: SettingsDep, simulator: SimulatorDep, q: str = "") -> dict[str, object]:
    await simulator.delay(0, settings.fast_latency_max_s)
    results = [f"{q or 'item'}-{n}" for n in range(1, 4)]
    return {"query": q, "results": results}


@router.post("/error")
async def trigger_error() -> None:
    raise TriggeredError("Error triggered from the UI")
