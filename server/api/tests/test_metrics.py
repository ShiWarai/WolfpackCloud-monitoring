"""
Тесты для API приёма метрик от роботов.
"""

from unittest.mock import AsyncMock, patch

import pytest
from fastapi import status
from httpx import AsyncClient


@pytest.fixture
def mock_influxdb():
    """Мок для InfluxDB запросов."""
    with patch("app.routers.metrics.httpx.AsyncClient") as mock:
        mock_response = AsyncMock()
        mock_response.status_code = 204
        mock_response.text = ""
        
        mock_client = AsyncMock()
        mock_client.post.return_value = mock_response
        mock_client.__aenter__.return_value = mock_client
        mock_client.__aexit__.return_value = None
        
        mock.return_value = mock_client
        yield mock


@pytest.fixture
async def active_robot_token(client: AsyncClient) -> str:
    """Создаёт активного робота и возвращает его токен."""
    pair_code = "METR1234"
    
    await client.post(
        "/api/pair",
        json={
            "hostname": "test-robot-metrics",
            "name": "Тестовый робот для метрик",
            "ip_address": "192.168.1.100",
            "architecture": "arm64",
            "pair_code": pair_code,
        },
    )
    
    confirm_response = await client.post(f"/api/pair/{pair_code}/confirm")
    return confirm_response.json()["influxdb_token"]


@pytest.fixture
async def inactive_robot_token(client: AsyncClient) -> str:
    """Создаёт неактивного робота (pending) и возвращает временный идентификатор."""
    pair_code = "INAC1234"
    
    reg_response = await client.post(
        "/api/pair",
        json={
            "hostname": "test-robot-inactive",
            "pair_code": pair_code,
        },
    )
    return f"pending_{pair_code}"


@pytest.mark.asyncio
async def test_metrics_valid_token(client: AsyncClient, active_robot_token: str, mock_influxdb):
    """Метрики принимаются с валидным токеном."""
    metrics_data = "cpu_usage,robot=test value=50.0 1234567890000000000"
    
    response = await client.post(
        "/api/metrics",
        content=metrics_data,
        headers={
            "Authorization": f"Bearer {active_robot_token}",
            "Content-Type": "text/plain",
        },
    )
    
    assert response.status_code == status.HTTP_204_NO_CONTENT


@pytest.mark.asyncio
async def test_metrics_invalid_token(client: AsyncClient):
    """401 при невалидном токене."""
    metrics_data = "cpu_usage,robot=test value=50.0 1234567890000000000"
    
    response = await client.post(
        "/api/metrics",
        content=metrics_data,
        headers={
            "Authorization": "Bearer invalid_token_12345",
            "Content-Type": "text/plain",
        },
    )
    
    assert response.status_code == status.HTTP_401_UNAUTHORIZED
    data = response.json()
    assert "detail" in data


@pytest.mark.asyncio
async def test_metrics_inactive_robot(client: AsyncClient):
    """403 если робот не активен (pending)."""
    pair_code = "PEND1234"
    
    await client.post(
        "/api/pair",
        json={
            "hostname": "test-robot-pending",
            "pair_code": pair_code,
        },
    )
    
    metrics_data = "cpu_usage,robot=test value=50.0 1234567890000000000"
    
    response = await client.post(
        "/api/metrics",
        content=metrics_data,
        headers={
            "Authorization": f"Bearer pending_{pair_code}",
            "Content-Type": "text/plain",
        },
    )
    
    assert response.status_code == status.HTTP_401_UNAUTHORIZED


@pytest.mark.asyncio
async def test_metrics_no_auth_header(client: AsyncClient):
    """401 без заголовка Authorization."""
    metrics_data = "cpu_usage,robot=test value=50.0 1234567890000000000"
    
    response = await client.post(
        "/api/metrics",
        content=metrics_data,
        headers={
            "Content-Type": "text/plain",
        },
    )
    
    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


@pytest.mark.asyncio
async def test_metrics_malformed_auth_header(client: AsyncClient):
    """401 при неверном формате заголовка Authorization."""
    metrics_data = "cpu_usage,robot=test value=50.0 1234567890000000000"
    
    response = await client.post(
        "/api/metrics",
        content=metrics_data,
        headers={
            "Authorization": "InvalidFormat token123",
            "Content-Type": "text/plain",
        },
    )
    
    assert response.status_code == status.HTTP_401_UNAUTHORIZED


@pytest.mark.asyncio
async def test_metrics_empty_body(client: AsyncClient, active_robot_token: str, mock_influxdb):
    """400 при пустом теле запроса."""
    response = await client.post(
        "/api/metrics",
        content="",
        headers={
            "Authorization": f"Bearer {active_robot_token}",
            "Content-Type": "text/plain",
        },
    )
    
    assert response.status_code == status.HTTP_400_BAD_REQUEST


@pytest.mark.asyncio
async def test_metrics_updates_last_seen(client: AsyncClient, mock_influxdb):
    """Проверка обновления last_seen_at робота после отправки метрик."""
    pair_code = "SEEN1234"
    
    reg_response = await client.post(
        "/api/pair",
        json={
            "hostname": "test-robot-last-seen",
            "pair_code": pair_code,
        },
    )
    robot_id = reg_response.json()["robot_id"]
    
    confirm_response = await client.post(f"/api/pair/{pair_code}/confirm")
    token = confirm_response.json()["influxdb_token"]
    
    robot_before = await client.get(f"/api/robots/{robot_id}")
    last_seen_before = robot_before.json().get("last_seen_at")
    
    metrics_data = "cpu_usage,robot=test value=50.0 1234567890000000000"
    await client.post(
        "/api/metrics",
        content=metrics_data,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "text/plain",
        },
    )
    
    robot_after = await client.get(f"/api/robots/{robot_id}")
    last_seen_after = robot_after.json().get("last_seen_at")
    
    assert last_seen_after is not None
    assert last_seen_after != last_seen_before or last_seen_before is None


@pytest.mark.asyncio
async def test_metrics_multiple_lines(client: AsyncClient, active_robot_token: str, mock_influxdb):
    """Метрики принимаются с несколькими строками данных."""
    metrics_data = """cpu_usage,robot=test,cpu=cpu0 value=50.0 1234567890000000000
cpu_usage,robot=test,cpu=cpu1 value=60.0 1234567890000000000
mem_usage,robot=test value=70.0 1234567890000000000"""
    
    response = await client.post(
        "/api/metrics",
        content=metrics_data,
        headers={
            "Authorization": f"Bearer {active_robot_token}",
            "Content-Type": "text/plain",
        },
    )
    
    assert response.status_code == status.HTTP_204_NO_CONTENT
