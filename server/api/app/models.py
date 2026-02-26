"""
SQLAlchemy ORM модели.

Определяет структуру таблиц для хранения информации о роботах и кодах привязки.
"""

import enum
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class RobotStatus(enum.StrEnum):
    """Статусы робота."""

    PENDING = "pending"
    ACTIVE = "active"
    INACTIVE = "inactive"
    ERROR = "error"


class Architecture(enum.StrEnum):
    """Архитектура процессора."""

    ARM64 = "arm64"
    AMD64 = "amd64"
    ARMHF = "armhf"


class PairCodeStatus(enum.StrEnum):
    """Статусы кода привязки."""

    PENDING = "pending"
    CONFIRMED = "confirmed"
    EXPIRED = "expired"


class Robot(Base):
    """Модель робота."""

    __tablename__ = "robots"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    hostname: Mapped[str] = mapped_column(String(255), nullable=False)
    ip_address: Mapped[str | None] = mapped_column(String(45))
    architecture: Mapped[Architecture] = mapped_column(
        Enum(Architecture), nullable=False, default=Architecture.ARM64
    )
    status: Mapped[RobotStatus] = mapped_column(
        Enum(RobotStatus), nullable=False, default=RobotStatus.PENDING
    )
    influxdb_token: Mapped[str | None] = mapped_column(Text)
    description: Mapped[str | None] = mapped_column(Text)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    # Связь с кодами привязки
    pair_codes: Mapped[list["PairCode"]] = relationship(
        "PairCode", back_populates="robot", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        return f"<Robot(id={self.id}, name={self.name}, status={self.status})>"


class PairCode(Base):
    """Модель кода привязки."""

    __tablename__ = "pair_codes"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    code: Mapped[str] = mapped_column(String(8), unique=True, nullable=False, index=True)
    robot_id: Mapped[int] = mapped_column(ForeignKey("robots.id"), nullable=False)
    status: Mapped[PairCodeStatus] = mapped_column(
        Enum(PairCodeStatus), nullable=False, default=PairCodeStatus.PENDING
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    confirmed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    # Связь с роботом
    robot: Mapped["Robot"] = relationship("Robot", back_populates="pair_codes")

    def __repr__(self) -> str:
        return f"<PairCode(code={self.code}, status={self.status})>"
