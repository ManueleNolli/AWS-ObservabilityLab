import random

import pytest

from observability_lab.services.auth import AuthService
from observability_lab.services.errors import InvalidCredentialsError
from observability_lab.services.simulator import Simulator

pytestmark = pytest.mark.anyio


def make_service(failure_rate: float) -> AuthService:
    return AuthService(Simulator(random.Random(0)), failure_rate=failure_rate, max_latency_s=0)


async def test_login_succeeds_when_failures_are_disabled() -> None:
    await make_service(failure_rate=0).login()


async def test_login_is_rejected_at_the_configured_rate() -> None:
    with pytest.raises(InvalidCredentialsError):
        await make_service(failure_rate=1).login()
