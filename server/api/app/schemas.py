"""
Pydantic схемы для валидации запросов и ответов API.
"""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models import Architecture, PairCodeStatus, RobotStatus

__all__ = [
    "Architecture",
    "PairCodeStatus",
    "RobotStatus",
]


# =============================================================================
# Схемы для роботов
# =============================================================================


class RobotBase(BaseModel):
    """Базовая схема робота."""

    name: str = Field(..., min_length=1, max_length=255, description="Имя робота")
    hostname: str = Field(..., min_length=1, max_length=255, description="Hostname устройства")
    ip_address: str | None = Field(None, max_length=45, description="IP-адрес")
    architecture: Architecture = Field(default=Architecture.ARM64, description="Архитектура")
    description: str | None = Field(None, description="Описание робота")


class RobotCreate(RobotBase):
    """Схема для создания робота (при привязке)."""

    pair_code: str = Field(
        ...,
        min_length=8,
        max_length=8,
        pattern=r"^[A-Z0-9]{8}$",
        description="8-значный код привязки",
    )


class RobotUpdate(BaseModel):
    """Схема для обновления робота."""

    name: str | None = Field(None, min_length=1, max_length=255)
    description: str | None = None
    status: RobotStatus | None = None


class RobotResponse(RobotBase):
    """Схема ответа с информацией о роботе."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    status: RobotStatus
    created_at: datetime
    updated_at: datetime
    last_seen_at: datetime | None = None


class RobotDetailResponse(RobotResponse):
    """Расширенная схема с дополнительной информацией."""

    influxdb_token: str | None = Field(None, description="Токен InfluxDB (только для API)")


class RobotListResponse(BaseModel):
    """Схема списка роботов."""

    robots: list[RobotResponse]
    total: int


# =============================================================================
# Схемы для привязки
# =============================================================================


class PairRequest(BaseModel):
    """Запрос на регистрацию робота (от агента)."""

    hostname: str = Field(..., min_length=1, max_length=255)
    name: str | None = Field(None, max_length=255)
    ip_address: str | None = Field(None, max_length=45)
    architecture: Architecture = Field(default=Architecture.ARM64)
    pair_code: str = Field(
        ...,
        min_length=8,
        max_length=8,
        pattern=r"^[A-Z0-9]{8}$",
        description="8-значный код привязки",
    )


class PairResponse(BaseModel):
    """Ответ на запрос привязки."""

    robot_id: int
    pair_code: str
    status: PairCodeStatus
    expires_at: datetime
    influxdb_token: str | None = Field(
        None, description="Токен InfluxDB (выдаётся после подтверждения)"
    )
    message: str


class PairConfirmRequest(BaseModel):
    """Запрос на подтверждение привязки (от пользователя)."""

    robot_name: str | None = Field(None, max_length=255, description="Новое имя робота")


class PairConfirmResponse(BaseModel):
    """Ответ на подтверждение привязки."""

    robot_id: int
    status: RobotStatus
    influxdb_token: str
    message: str


class PairCodeInfoResponse(BaseModel):
    """Информация о коде привязки."""

    model_config = ConfigDict(from_attributes=True)

    code: str
    status: PairCodeStatus
    created_at: datetime
    expires_at: datetime
    robot: RobotResponse | None = None


class PairStatusResponse(BaseModel):
    """Статус привязки для polling агентом."""

    status: PairCodeStatus
    robot_id: int | None = None
    robot_token: str | None = Field(
        None, description="Токен для отправки метрик (только после подтверждения)"
    )
    api_url: str = Field(..., description="URL API для отправки метрик")
    message: str


# =============================================================================
# Общие схемы
# =============================================================================


class HealthResponse(BaseModel):
    """Схема ответа health check."""

    status: str = "ok"
    version: str
    database: str = "connected"
    influxdb: str = "connected"


class ErrorResponse(BaseModel):
    """Схема ошибки."""

    detail: str
    error_code: str | None = None
