import logging
from dataclasses import dataclass

from observability_lab.services.errors import InvalidCredentialsError
from observability_lab.services.simulator import Simulator

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class AuthService:
    simulator: Simulator
    failure_rate: float
    max_latency_s: float

    async def login(self) -> None:
        """Pretend to check credentials; rejects a share of attempts at random."""
        await self.simulator.delay(0, self.max_latency_s)
        if self.simulator.fails(self.failure_rate):
            logger.warning("login rejected", extra={"reason": "invalid_credentials"})
            raise InvalidCredentialsError
