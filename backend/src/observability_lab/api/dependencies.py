"""Gives route handlers the services created at startup (see ``app.build_services``)."""

from typing import Annotated

from fastapi import Depends, Request

from observability_lab.services import Services


def get_services(request: Request) -> Services:
    return request.app.state.services


# Declare a handler parameter as `services: ServicesDep` and FastAPI passes the services in.
ServicesDep = Annotated[Services, Depends(get_services)]
