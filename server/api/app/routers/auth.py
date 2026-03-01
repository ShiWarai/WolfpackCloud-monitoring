"""
API эндпоинты для аутентификации пользователей.

Обеспечивает регистрацию, вход и управление JWT токенами.
"""

from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.database import get_db
from app.deps import get_current_user
from app.models import User, UserRole
from app.services.external_auth import ExternalAuthService
from app.schemas import (
    ErrorResponse,
    RefreshTokenRequest,
    TokenResponse,
    UserCreate,
    UserLogin,
    UserResponse,
)

router = APIRouter(prefix="/api/auth", tags=["auth"])
settings = get_settings()

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Проверяет пароль."""
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    """Хэширует пароль."""
    return pwd_context.hash(password)


def create_access_token(data: dict, expires_delta: timedelta | None = None) -> str:
    """Создаёт access токен."""
    to_encode = data.copy()
    expire = datetime.now(UTC) + (expires_delta or timedelta(minutes=15))
    to_encode.update({"exp": expire, "type": "access"})
    return jwt.encode(to_encode, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def create_refresh_token(data: dict, expires_delta: timedelta | None = None) -> str:
    """Создаёт refresh токен."""
    to_encode = data.copy()
    expire = datetime.now(UTC) + (expires_delta or timedelta(days=7))
    to_encode.update({"exp": expire, "type": "refresh"})
    return jwt.encode(to_encode, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


# =============================================================================
# РЕГИСТРАЦИЯ ОТКЛЮЧЕНА
# Используется единственный аккаунт администратора.
# Для включения регистрации раскомментируйте код ниже.
# =============================================================================
#
# @router.post(
#     "/register",
#     response_model=UserResponse,
#     status_code=status.HTTP_201_CREATED,
#     responses={
#         409: {"model": ErrorResponse, "description": "Email уже зарегистрирован"},
#     },
#     summary="Регистрация пользователя",
#     description="Создаёт нового пользователя в системе.",
# )
# async def register(
#     request: UserCreate,
#     db: AsyncSession = Depends(get_db),
# ) -> UserResponse:
#     """Регистрирует нового пользователя."""
#     existing = await db.execute(select(User).where(User.email == request.email.lower()))
#     if existing.scalar_one_or_none():
#         raise HTTPException(
#             status_code=status.HTTP_409_CONFLICT,
#             detail="Пользователь с таким email уже существует",
#         )
#
#     user = User(
#         email=request.email.lower(),
#         hashed_password=get_password_hash(request.password),
#         name=request.name,
#         role=UserRole.USER,
#         is_active=True,
#     )
#     db.add(user)
#     await db.commit()
#     await db.refresh(user)
#
#     ext_auth = ExternalAuthService(settings)
#     grafana_id = await ext_auth.create_grafana_user(
#         email=user.email, password=request.password, name=user.name
#     )
#     superset_id = await ext_auth.create_superset_user(
#         email=user.email, password=request.password, name=user.name
#     )
#     if grafana_id is not None or superset_id is not None:
#         user.grafana_user_id = grafana_id
#         user.superset_user_id = superset_id
#         await db.commit()
#         await db.refresh(user)
#
#     return UserResponse.model_validate(user)


@router.post(
    "/login",
    response_model=TokenResponse,
    responses={
        401: {"model": ErrorResponse, "description": "Неверные учётные данные"},
    },
    summary="Вход в систему",
    description="Аутентификация по email и паролю. Возвращает JWT токены.",
)
async def login(
    request: UserLogin,
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
    """Аутентификация пользователя."""
    result = await db.execute(select(User).where(User.email == request.email.lower()))
    user = result.scalar_one_or_none()

    if not user or not verify_password(request.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Неверный email или пароль",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Аккаунт деактивирован",
        )

    access_token = create_access_token(
        data={"sub": str(user.id)},
        expires_delta=timedelta(minutes=settings.jwt_access_token_expire_minutes),
    )
    refresh_token = create_refresh_token(
        data={"sub": str(user.id)},
        expires_delta=timedelta(days=settings.jwt_refresh_token_expire_days),
    )

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        expires_in=settings.jwt_access_token_expire_minutes * 60,
    )


@router.post(
    "/refresh",
    response_model=TokenResponse,
    responses={
        401: {"model": ErrorResponse, "description": "Невалидный refresh токен"},
    },
    summary="Обновление токена",
    description="Обновляет access токен используя refresh токен.",
)
async def refresh_tokens(
    request: RefreshTokenRequest,
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
    """Обновляет токены по refresh токену."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Невалидный refresh токен",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        payload = jwt.decode(
            request.refresh_token,
            settings.jwt_secret_key,
            algorithms=[settings.jwt_algorithm],
        )
        user_id: str = payload.get("sub")
        token_type: str = payload.get("type")

        if user_id is None or token_type != "refresh":
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    result = await db.execute(select(User).where(User.id == int(user_id)))
    user = result.scalar_one_or_none()

    if user is None or not user.is_active:
        raise credentials_exception

    new_access_token = create_access_token(
        data={"sub": str(user.id)},
        expires_delta=timedelta(minutes=settings.jwt_access_token_expire_minutes),
    )
    new_refresh_token = create_refresh_token(
        data={"sub": str(user.id)},
        expires_delta=timedelta(days=settings.jwt_refresh_token_expire_days),
    )

    return TokenResponse(
        access_token=new_access_token,
        refresh_token=new_refresh_token,
        token_type="bearer",
        expires_in=settings.jwt_access_token_expire_minutes * 60,
    )


@router.get(
    "/me",
    response_model=UserResponse,
    summary="Текущий пользователь",
    description="Возвращает информацию о текущем авторизованном пользователе.",
)
async def get_me(
    current_user: User = Depends(get_current_user),
) -> UserResponse:
    """Возвращает текущего пользователя."""
    return UserResponse.model_validate(current_user)
