"""
Роутеры API.
"""

from app.routers.auth import router as auth_router
from app.routers.metrics import router as metrics_router
from app.routers.pairing import router as pairing_router
from app.routers.robots import router as robots_router

__all__ = ["auth_router", "metrics_router", "pairing_router", "robots_router"]
