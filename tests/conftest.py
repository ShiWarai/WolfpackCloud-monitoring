"""Конфигурация pytest для интеграционных тестов."""

import pytest


@pytest.fixture(scope="session")
def anyio_backend():
    """Бэкенд для anyio."""
    return "asyncio"
