import logging
import uuid
from dataclasses import dataclass

from observability_lab.services.errors import PaymentProviderError
from observability_lab.services.simulator import Simulator

logger = logging.getLogger(__name__)

RESULTS_PER_SEARCH = 3


@dataclass(frozen=True)
class ShopService:
    simulator: Simulator
    checkout_error_rate: float
    checkout_min_latency_s: float
    checkout_max_latency_s: float
    search_max_latency_s: float

    async def checkout(self) -> str:
        """Place an order and return its ID. Slow, and fails at random."""
        await self.simulator.delay(self.checkout_min_latency_s, self.checkout_max_latency_s)
        if self.simulator.fails(self.checkout_error_rate):
            logger.error("checkout failed", extra={"reason": "payment_provider_unavailable"})
            raise PaymentProviderError
        return uuid.uuid4().hex

    async def search(self, query: str) -> list[str]:
        await self.simulator.delay(0, self.search_max_latency_s)
        term = query or "item"
        return [f"{term}-{n}" for n in range(1, RESULTS_PER_SEARCH + 1)]
