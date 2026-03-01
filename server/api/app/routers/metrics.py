"""
API эндпоинт для приёма метрик от роботов.

Роботы отправляют метрики через этот эндпоинт с авторизацией по персональному токену.
API проксирует данные в InfluxDB.
"""

import gzip
from datetime import UTC, datetime

import httpx
from fastapi import APIRouter, Depends, Header, HTTPException, Request, Response, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.database import get_db
from app.models import Robot, RobotStatus
from app.schemas import ErrorResponse

router = APIRouter(prefix="/api/metrics", tags=["metrics"])
settings = get_settings()


async def get_robot_by_token(
    authorization: str = Header(..., description="Bearer {robot_token}"),
    db: AsyncSession = Depends(get_db),
) -> Robot:
    """
    Извлекает робота по токену из заголовка Authorization.

    Raises:
        HTTPException: 401 если токен невалидный, 403 если робот не активен
    """
    if not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Неверный формат заголовка Authorization. Ожидается: Bearer {token}",
        )

    token = authorization[7:]

    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Токен не указан",
        )

    result = await db.execute(select(Robot).where(Robot.influxdb_token == token))
    robot = result.scalar_one_or_none()

    if not robot:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Невалидный токен",
        )

    if robot.status != RobotStatus.ACTIVE:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Робот не активен. Текущий статус: {robot.status}",
        )

    return robot


@router.post(
    "",
    status_code=status.HTTP_204_NO_CONTENT,
    responses={
        401: {"model": ErrorResponse, "description": "Невалидный токен"},
        403: {"model": ErrorResponse, "description": "Робот не активен"},
        502: {"model": ErrorResponse, "description": "Ошибка записи в InfluxDB"},
    },
    summary="Приём метрик от робота",
    description="""
Принимает метрики в формате InfluxDB Line Protocol и записывает в InfluxDB.

Требуется заголовок `Authorization: Bearer {robot_token}`.

Токен робот получает после подтверждения привязки через `GET /api/pair/{code}/status`.
    """,
)
async def receive_metrics(
    request: Request,
    robot: Robot = Depends(get_robot_by_token),
    db: AsyncSession = Depends(get_db),
) -> Response:
    """
    Принимает метрики от робота и записывает в InfluxDB.

    1. Валидирует токен робота
    2. Читает тело запроса (InfluxDB Line Protocol)
    3. Распаковывает gzip если нужно
    4. Пересылает в InfluxDB
    5. Обновляет last_seen_at робота
    """
    body = await request.body()

    if not body:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Тело запроса пустое",
        )

    content_encoding = request.headers.get("content-encoding", "").lower()
    if content_encoding == "gzip":
        try:
            body = gzip.decompress(body)
        except gzip.BadGzipFile:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Невалидные gzip данные",
            )

    influx_url = f"{settings.influxdb_url}/api/v2/write"
    params = {
        "org": settings.influxdb_org,
        "bucket": settings.influxdb_bucket,
        "precision": "ns",
    }

    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(
                influx_url,
                params=params,
                headers={
                    "Authorization": f"Token {settings.influxdb_token}",
                    "Content-Type": "text/plain; charset=utf-8",
                },
                content=body,
                timeout=10.0,
            )

            if response.status_code not in (200, 204):
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail=f"InfluxDB вернул ошибку: {response.status_code} - {response.text}",
                )
        except httpx.RequestError as e:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Ошибка соединения с InfluxDB: {str(e)}",
            )

    robot.last_seen_at = datetime.now(UTC)
    await db.commit()

    return Response(status_code=status.HTTP_204_NO_CONTENT)
