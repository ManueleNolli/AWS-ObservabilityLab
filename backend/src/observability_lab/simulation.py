"""Randomised latency and failures that make the demo endpoints interesting to observe."""

import asyncio
import random


class Simulator:
    def __init__(self, rng: random.Random | None = None) -> None:
        self._rng = rng or random.Random()

    async def delay(self, low_s: float, high_s: float) -> None:
        """Sleep for a uniformly random duration in ``[low_s, high_s]``."""
        duration = self._rng.uniform(low_s, high_s)
        if duration > 0:
            await asyncio.sleep(duration)

    def fails(self, rate: float) -> bool:
        """Return ``True`` with probability ``rate``."""
        return self._rng.random() < rate
