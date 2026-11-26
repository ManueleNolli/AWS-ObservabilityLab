import random

import pytest

from observability_lab.services.simulator import Simulator


@pytest.mark.parametrize(("rate", "expected"), [(0, False), (1, True)])
def test_fails_respects_extreme_rates(rate: float, expected: bool) -> None:
    simulator = Simulator(random.Random(0))

    assert all(simulator.fails(rate) is expected for _ in range(100))


def test_fails_roughly_matches_the_rate() -> None:
    simulator = Simulator(random.Random(0))

    failures = sum(simulator.fails(0.2) for _ in range(10_000))

    assert 1_800 < failures < 2_200
