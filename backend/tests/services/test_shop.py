import random

import pytest

from observability_lab.services.errors import PaymentProviderError
from observability_lab.services.shop import RESULTS_PER_SEARCH, ShopService
from observability_lab.services.simulator import Simulator

pytestmark = pytest.mark.anyio


def make_service(checkout_error_rate: float = 0) -> ShopService:
    return ShopService(
        Simulator(random.Random(0)),
        checkout_error_rate=checkout_error_rate,
        checkout_min_latency_s=0,
        checkout_max_latency_s=0,
        search_max_latency_s=0,
    )


async def test_checkout_returns_a_new_order_id() -> None:
    service = make_service()

    first, second = await service.checkout(), await service.checkout()

    assert first != second


async def test_checkout_fails_at_the_configured_rate() -> None:
    with pytest.raises(PaymentProviderError):
        await make_service(checkout_error_rate=1).checkout()


async def test_search_returns_results_for_the_query() -> None:
    results = await make_service().search("shoes")

    assert len(results) == RESULTS_PER_SEARCH
    assert all(result.startswith("shoes-") for result in results)
