"""
SQLAlchemy ORM модели.

Определяет структуру таблиц для хранения информации о пользователях, роботах и кодах привязки.
"""

import enum
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class UserRole(enum.StrEnum):
    """Роли пользователей."""

    USER = "user"
    ADMIN = "admin"


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


class User(Base):
    """Модель пользователя."""

    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[UserRole] = mapped_column(
        Enum(UserRole, name="user_role", values_callable=lambda x: [e.value for e in x]),
        nullable=False,
        default=UserRole.USER,
    )
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    robots: Mapped[list["Robot"]] = relationship("Robot", back_populates="owner")

    def __repr__(self) -> str:
        return f"<User(id={self.id}, email={self.email}, role={self.role})>"


class Robot(Base):
    """Модель робота."""

    __tablename__ = "robots"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    hostname: Mapped[str] = mapped_column(String(255), nullable=False)
    ip_address: Mapped[str | None] = mapped_column(String(45))
    architecture: Mapped[Architecture] = mapped_column(
        Enum(Architecture, name="architecture", values_callable=lambda x: [e.value for e in x]),
        nullable=False,
        default=Architecture.ARM64,
    )
    status: Mapped[RobotStatus] = mapped_column(
        Enum(RobotStatus, name="robot_status", values_callable=lambda x: [e.value for e in x]),
        nullable=False,
        default=RobotStatus.PENDING,
    )
    influxdb_token: Mapped[str | None] = mapped_column(Text)
    description: Mapped[str | None] = mapped_column(Text)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    owner_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"))
    owner: Mapped["User | None"] = relationship("User", back_populates="robots")

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
        Enum(PairCodeStatus, name="pair_code_status", values_callable=lambda x: [e.value for e in x]),
        nullable=False,
        default=PairCodeStatus.PENDING,
    )

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    confirmed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    # Связь с роботом
    robot: Mapped["Robot"] = relationship("Robot", back_populates="pair_codes")

    def __repr__(self) -> str:
        return f"<PairCode(code={self.code}, status={self.status})>"
