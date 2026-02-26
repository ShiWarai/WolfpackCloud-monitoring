"""
API эндпоинты для управления роботами.

CRUD операции над зарегистрированными роботами.
"""

from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import Robot, RobotStatus
from app.schemas import (
    ErrorResponse,
    RobotDetailResponse,
    RobotListResponse,
    RobotResponse,
    RobotUpdate,
)

router = APIRouter(prefix="/api/robots", tags=["robots"])


@router.get(
    "",
    response_model=RobotListResponse,
    summary="Список роботов",
    description="Получение списка всех зарегистрированных роботов с пагинацией и фильтрацией.",
)
async def list_robots(
    status_filter: RobotStatus | None = Query(None, alias="status", description="Фильтр по статусу"),
    search: str | None = Query(None, description="Поиск по имени или hostname"),
    skip: int = Query(0, ge=0, description="Пропустить записей"),
    limit: int = Query(50, ge=1, le=100, description="Максимум записей"),
    db: AsyncSession = Depends(get_db),
) -> RobotListResponse:
    """Возвращает список роботов с возможностью фильтрации."""
    query = select(Robot)

    # Фильтрация по статусу
    if status_filter:
        query = query.where(Robot.status == status_filter)

    # Поиск по имени или hostname
    if search:
        search_pattern = f"%{search}%"
        query = query.where(
            (Robot.name.ilike(search_pattern)) | (Robot.hostname.ilike(search_pattern))
        )

    # Подсчёт общего количества
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar_one()

    # Пагинация и сортировка
    query = query.order_by(Robot.created_at.desc()).offset(skip).limit(limit)

    result = await db.execute(query)
    robots = result.scalars().all()

    return RobotListResponse(
        robots=[RobotResponse.model_validate(r) for r in robots],
        total=total,
    )


@router.get(
    "/{robot_id}",
    response_model=RobotDetailResponse,
    responses={
        404: {"model": ErrorResponse, "description": "Робот не найден"},
    },
    summary="Информация о роботе",
    description="Получение детальной информации о роботе по ID.",
)
async def get_robot(
    robot_id: int,
    db: AsyncSession = Depends(get_db),
) -> RobotDetailResponse:
    """Возвращает информацию о роботе."""
    result = await db.execute(select(Robot).where(Robot.id == robot_id))
    robot = result.scalar_one_or_none()

    if not robot:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Робот не найден",
        )

    return RobotDetailResponse.model_validate(robot)


@router.patch(
    "/{robot_id}",
    response_model=RobotResponse,
    responses={
        404: {"model": ErrorResponse, "description": "Робот не найден"},
    },
    summary="Обновление робота",
    description="Частичное обновление информации о роботе.",
)
async def update_robot(
    robot_id: int,
    update_data: RobotUpdate,
    db: AsyncSession = Depends(get_db),
) -> RobotResponse:
    """Обновляет информацию о роботе."""
    result = await db.execute(select(Robot).where(Robot.id == robot_id))
    robot = result.scalar_one_or_none()

    if not robot:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Робот не найден",
        )

    # Обновляем только переданные поля
    update_dict = update_data.model_dump(exclude_unset=True)
    for field, value in update_dict.items():
        setattr(robot, field, value)

    robot.updated_at = datetime.now(UTC)
    await db.commit()
    await db.refresh(robot)

    return RobotResponse.model_validate(robot)


@router.delete(
    "/{robot_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    responses={
        404: {"model": ErrorResponse, "description": "Робот не найден"},
    },
    summary="Удаление робота",
    description="Удаляет робота из системы мониторинга.",
)
async def delete_robot(
    robot_id: int,
    db: AsyncSession = Depends(get_db),
) -> None:
    """Удаляет робота."""
    result = await db.execute(select(Robot).where(Robot.id == robot_id))
    robot = result.scalar_one_or_none()

    if not robot:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Робот не найден",
        )

    await db.delete(robot)
    await db.commit()


@router.post(
    "/{robot_id}/heartbeat",
    response_model=RobotResponse,
    responses={
        404: {"model": ErrorResponse, "description": "Робот не найден"},
    },
    summary="Heartbeat робота",
    description="Обновляет время последней активности робота.",
)
async def robot_heartbeat(
    robot_id: int,
    db: AsyncSession = Depends(get_db),
) -> RobotResponse:
    """Обновляет время последней активности робота."""
    result = await db.execute(select(Robot).where(Robot.id == robot_id))
    robot = result.scalar_one_or_none()

    if not robot:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Робот не найден",
        )

    robot.last_seen_at = datetime.now(UTC)
    if robot.status == RobotStatus.INACTIVE:
        robot.status = RobotStatus.ACTIVE

    await db.commit()
    await db.refresh(robot)

    return RobotResponse.model_validate(robot)
