from fastapi import APIRouter

from observability_lab.api import API_PREFIX
from observability_lab.api.routes import auth, errors, health, shop

HEALTH_PATH = API_PREFIX + health.PATH

ROUTERS: tuple[APIRouter, ...] = (health.router, auth.router, shop.router, errors.router)
