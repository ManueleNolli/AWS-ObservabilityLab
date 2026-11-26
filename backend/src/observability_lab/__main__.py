"""Entry point: ``python -m observability_lab``."""

import uvicorn

from observability_lab.app import create_app
from observability_lab.config import Settings
from observability_lab.observability.logs import configure_logging


def main() -> None:
    settings = Settings()
    configure_logging(settings.log_level)
    uvicorn.run(
        create_app(settings),
        host=settings.host,
        port=settings.port,
        log_config=None,  # keep the JSON logging configured above
        access_log=False,  # ObservabilityMiddleware writes the access log
        proxy_headers=True,
        forwarded_allow_ips="*",  # only reachable through the load balancer / local proxy
    )


if __name__ == "__main__":
    main()
