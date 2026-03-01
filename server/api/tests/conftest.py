"""
Конфигурация pytest.
"""

import asyncio
import os
from collections.abc import AsyncGenerator
from datetime import UTC, datetime, timedelta

import pytest
from httpx import ASGITransport, AsyncClient
from jose import jwt
from passlib.context import CryptContext
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.config import get_settings
from app.database import Base, get_db
from app.main import app
from app.models import User, UserRole

TEST_DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql+asyncpg://test:testpassword@localhost:5432/monitoring_test",
)

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
settings = get_settings()


@pytest.fixture(scope="session")
def event_loop():
    """Создание event loop для всей сессии тестов."""
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(scope="session")
async def test_engine():
    """Асинхронный движок для тестовой БД."""
    engine = create_async_engine(
        TEST_DATABASE_URL,
        poolclass=NullPool,
        echo=False,
    )
    yield engine
    await engine.dispose()


@pytest.fixture(scope="session")
async def setup_database(test_engine):
    """Создание таблиц перед тестами."""
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest.fixture
async def db_session(test_engine, setup_database) -> AsyncGenerator[AsyncSession, None]:  # noqa: ARG001
    """Сессия БД для каждого теста с откатом транзакции через SAVEPOINT."""
    async with test_engine.connect() as conn:
        trans = await conn.begin()
        async_session = async_sessionmaker(
            bind=conn,
            class_=AsyncSession,
            expire_on_commit=False,
            join_transaction_mode="create_savepoint",
        )
        async with async_session() as session:
            yield session
        await trans.rollback()


def create_test_access_token(user_id: int) -> str:
    """Создаёт тестовый JWT access токен."""
    expire = datetime.now(UTC) + timedelta(minutes=30)
    to_encode = {"sub": str(user_id), "exp": expire, "type": "access"}
    return jwt.encode(to_encode, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


@pytest.fixture
async def test_admin(db_session: AsyncSession) -> User:
    """Создаёт тестового администратора."""
    admin = User(
        email="admin@test.local",
        hashed_password=pwd_context.hash("testpassword"),
        name="Test Admin",
        role=UserRole.ADMIN,
        is_active=True,
    )
    db_session.add(admin)
    await db_session.commit()
    await db_session.refresh(admin)
    return admin


@pytest.fixture
async def admin_token(test_admin: User) -> str:
    """JWT токен для тестового администратора."""
    return create_test_access_token(test_admin.id)


@pytest.fixture
async def client(
    db_session: AsyncSession,
    test_admin: User,  # noqa: ARG001
    admin_token: str,
) -> AsyncGenerator[AsyncClient, None]:
    """Асинхронный HTTP клиент с подменённой БД и авторизацией админа."""

    async def override_get_db() -> AsyncGenerator[AsyncSession, None]:
        yield db_session

    app.dependency_overrides[get_db] = override_get_db

    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
        headers={"Authorization": f"Bearer {admin_token}"},
    ) as ac:
        yield ac

    app.dependency_overrides.clear()
