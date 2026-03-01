"""
Конфигурация приложения.

Загружает настройки из переменных окружения с использованием pydantic-settings.
"""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Настройки приложения."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # Приложение
    app_name: str = "WolfpackCloud Monitoring API"
    debug: bool = False
    api_base_url: str = "http://localhost:8000"

    # Безопасность
    secret_key: str = "dev-secret-key-change-in-production"
    pair_code_expiration_minutes: int = 15

    # JWT
    jwt_secret_key: str = "dev-jwt-secret-key-change-in-production"
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 30
    jwt_refresh_token_expire_days: int = 7

    # PostgreSQL
    database_url: str = "postgresql://monitoring:monitoring@localhost:5432/monitoring"

    # InfluxDB
    influxdb_url: str = "http://localhost:8086"
    influxdb_token: str = "dev-influxdb-token"
    influxdb_org: str = "wolfpackcloud"
    influxdb_bucket: str = "robots"

    # Grafana
    grafana_url: str = "http://localhost:3000"
    grafana_admin_user: str = "admin"
    grafana_admin_password: str = "admin"

    # Superset
    superset_url: str = "http://localhost:8088"
    superset_admin_username: str = "admin"
    superset_admin_password: str = "admin"

    # Администратор WolfpackCloud (создаётся при запуске)
    default_admin_email: str = "admin@wolfpackcloud.local"
    default_admin_password: str = "admin"
    default_admin_name: str = "Admin"

    @property
    def async_database_url(self) -> str:
        """Возвращает URL для asyncpg."""
        url = self.database_url
        if url.startswith("postgresql://"):
            url = url.replace("postgresql://", "postgresql+asyncpg://", 1)
        return url


@lru_cache
def get_settings() -> Settings:
    """Получить закэшированные настройки."""
    return Settings()
