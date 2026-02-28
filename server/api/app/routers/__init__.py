"""
Роутеры API.
"""

from app.routers.metrics import router as metrics_router
from app.routers.pairing import router as pairing_router
from app.routers.robots import router as robots_router

__all__ = ["metrics_router", "pairing_router", "robots_router"]
