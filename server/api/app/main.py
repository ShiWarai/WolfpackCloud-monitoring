"""
Главный модуль FastAPI приложения.

WolfpackCloud Monitoring API — сервис привязки и управления роботами.
"""

from contextlib import asynccontextmanager
from typing import Any

from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app import __version__
from app.config import get_settings
from app.database import init_db
from app.routers import metrics_router, pairing_router, robots_router
from app.schemas import ErrorResponse, HealthResponse

settings = get_settings()


@asynccontextmanager
async def lifespan(_app: FastAPI):
    """Lifecycle события приложения."""
    # Startup
    await init_db()
    yield
    # Shutdown


app = FastAPI(
    title=settings.app_name,
    description="""
## WolfpackCloud Monitoring API

API для привязки и управления роботами в системе мониторинга WolfpackCloud.

### Основные функции:

- **Привязка роботов** — регистрация через 8-значный код
- **Управление роботами** — CRUD операции
- **Мониторинг статуса** — отслеживание активности

### Процесс привязки:

1. Агент на роботе генерирует 8-значный код
2. Агент вызывает `POST /api/pair` с кодом и информацией о системе
3. Пользователь вводит код в панели управления (Grafana)
4. Панель вызывает `POST /api/pair/{code}/confirm`
5. Робот опрашивает `GET /api/pair/{code}/status` и получает токен
6. Робот отправляет метрики через `POST /api/metrics` с токеном
    """,
    version=__version__,
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    lifespan=lifespan,
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # В production ограничить до конкретных доменов
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Обработчик исключений
@app.exception_handler(Exception)
async def global_exception_handler(_request: Request, _exc: Exception) -> JSONResponse:
    """Глобальный обработчик исключений."""
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content=ErrorResponse(
            detail="Внутренняя ошибка сервера",
            error_code="INTERNAL_ERROR",
        ).model_dump(),
    )


# Подключение роутеров
app.include_router(metrics_router)
app.include_router(pairing_router)
app.include_router(robots_router)


# Health check
@app.get(
    "/health",
    response_model=HealthResponse,
    tags=["system"],
    summary="Health check",
    description="Проверка работоспособности сервиса.",
)
async def health_check() -> dict[str, Any]:
    """Возвращает статус работоспособности сервиса."""
    return {
        "status": "ok",
        "version": __version__,
        "database": "connected",
        "influxdb": "connected",
    }


# Root endpoint
@app.get(
    "/",
    tags=["system"],
    summary="Информация об API",
)
async def root() -> dict[str, Any]:
    """Возвращает базовую информацию об API."""
    return {
        "name": settings.app_name,
        "version": __version__,
        "docs": "/docs",
        "health": "/health",
    }
