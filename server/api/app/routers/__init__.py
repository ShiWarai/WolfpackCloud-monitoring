"""
Роутеры API.
"""

from app.routers.pairing import router as pairing_router
from app.routers.robots import router as robots_router

__all__ = ["pairing_router", "robots_router"]
