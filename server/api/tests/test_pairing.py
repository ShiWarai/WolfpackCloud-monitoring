"""
Тесты для API привязки роботов.
"""

import pytest
from fastapi import status
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_health_check(client: AsyncClient):
    """Тест health check эндпоинта."""
    response = await client.get("/health")
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["status"] == "ok"
    assert "version" in data


@pytest.mark.asyncio
async def test_root(client: AsyncClient):
    """Тест корневого эндпоинта."""
    response = await client.get("/")
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert "name" in data
    assert "version" in data


@pytest.mark.asyncio
async def test_register_robot(client: AsyncClient):
    """Тест регистрации робота."""
    pair_code = "ABCD1234"
    response = await client.post(
        "/api/pair",
        json={
            "hostname": "test-robot",
            "name": "Тестовый робот",
            "ip_address": "192.168.1.100",
            "architecture": "arm64",
            "pair_code": pair_code,
        },
    )
    assert response.status_code == status.HTTP_201_CREATED
    data = response.json()
    assert data["pair_code"] == pair_code
    assert data["status"] == "pending"
    assert "robot_id" in data
    assert "expires_at" in data


@pytest.mark.asyncio
async def test_register_robot_duplicate_code(client: AsyncClient):
    """Тест регистрации с дублирующимся кодом."""
    pair_code = "DUPL1234"

    # Первая регистрация
    response1 = await client.post(
        "/api/pair",
        json={
            "hostname": "robot1",
            "pair_code": pair_code,
        },
    )
    assert response1.status_code == status.HTTP_201_CREATED

    # Вторая регистрация с тем же кодом
    response2 = await client.post(
        "/api/pair",
        json={
            "hostname": "robot2",
            "pair_code": pair_code,
        },
    )
    assert response2.status_code == status.HTTP_409_CONFLICT


@pytest.mark.asyncio
async def test_get_pair_code_info(client: AsyncClient):
    """Тест получения информации о коде привязки."""
    pair_code = "INFO1234"

    # Регистрация
    await client.post(
        "/api/pair",
        json={
            "hostname": "test-robot-info",
            "pair_code": pair_code,
        },
    )

    # Получение информации
    response = await client.get(f"/api/pair/{pair_code}")
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["code"] == pair_code
    assert data["status"] == "pending"


@pytest.mark.asyncio
async def test_get_pair_code_not_found(client: AsyncClient):
    """Тест получения несуществующего кода."""
    response = await client.get("/api/pair/NOTFOUND")
    assert response.status_code == status.HTTP_404_NOT_FOUND


@pytest.mark.asyncio
async def test_confirm_pairing(client: AsyncClient):
    """Тест подтверждения привязки."""
    pair_code = "CONF1234"

    # Регистрация
    reg_response = await client.post(
        "/api/pair",
        json={
            "hostname": "test-confirm",
            "pair_code": pair_code,
        },
    )
    assert reg_response.status_code == status.HTTP_201_CREATED

    # Подтверждение
    confirm_response = await client.post(
        f"/api/pair/{pair_code}/confirm",
        json={"robot_name": "Подтверждённый робот"},
    )
    assert confirm_response.status_code == status.HTTP_200_OK
    data = confirm_response.json()
    assert data["status"] == "active"
    assert "influxdb_token" in data
    assert data["influxdb_token"] is not None


@pytest.mark.asyncio
async def test_confirm_already_confirmed(client: AsyncClient):
    """Тест повторного подтверждения."""
    pair_code = "DBLC1234"

    # Регистрация
    await client.post(
        "/api/pair",
        json={
            "hostname": "test-double-confirm",
            "pair_code": pair_code,
        },
    )

    # Первое подтверждение
    await client.post(f"/api/pair/{pair_code}/confirm")

    # Повторное подтверждение
    response = await client.post(f"/api/pair/{pair_code}/confirm")
    assert response.status_code == status.HTTP_400_BAD_REQUEST


@pytest.mark.asyncio
async def test_list_robots(client: AsyncClient):
    """Тест получения списка роботов."""
    response = await client.get("/api/robots")
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert "robots" in data
    assert "total" in data
    assert isinstance(data["robots"], list)


@pytest.mark.asyncio
async def test_get_robot_not_found(client: AsyncClient):
    """Тест получения несуществующего робота."""
    response = await client.get("/api/robots/99999")
    assert response.status_code == status.HTTP_404_NOT_FOUND


@pytest.mark.asyncio
async def test_delete_robot(client: AsyncClient):
    """Тест удаления робота."""
    pair_code = "DELE1234"

    # Регистрация
    reg_response = await client.post(
        "/api/pair",
        json={
            "hostname": "test-delete",
            "pair_code": pair_code,
        },
    )
    robot_id = reg_response.json()["robot_id"]

    # Удаление
    delete_response = await client.delete(f"/api/robots/{robot_id}")
    assert delete_response.status_code == status.HTTP_204_NO_CONTENT

    # Проверка удаления
    get_response = await client.get(f"/api/robots/{robot_id}")
    assert get_response.status_code == status.HTTP_404_NOT_FOUND
