"""Runtime settings, read from ``LAB_*`` environment variables."""

from typing import Self

from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="LAB_")

    host: str = "0.0.0.0"
    port: int = 8000
    # Served on its own port so it can be exposed inside the VPC only.
    metrics_port: int = 9100
    log_level: str = "INFO"

    # Simulated behaviour of the demo endpoints.
    login_failure_rate: float = Field(default=0.2, ge=0, le=1)
    checkout_error_rate: float = Field(default=0.1, ge=0, le=1)
    checkout_latency_min_s: float = Field(default=0.5, ge=0)
    checkout_latency_max_s: float = Field(default=2.5, ge=0)
    fast_latency_max_s: float = Field(default=0.15, ge=0)

    @model_validator(mode="after")
    def _check_latency_range(self) -> Self:
        if self.checkout_latency_min_s > self.checkout_latency_max_s:
            raise ValueError("checkout_latency_min_s must not exceed checkout_latency_max_s")
        return self
