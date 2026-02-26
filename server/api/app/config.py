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
    secret_key: str = "change-me-in-production"
    pair_code_expiration_minutes: int = 15

    # PostgreSQL
    database_url: str = "postgresql+asyncpg://monitoring:monitoring@localhost:5432/monitoring"

    # InfluxDB
    influxdb_url: str = "http://localhost:8086"
    influxdb_token: str = ""
    influxdb_org: str = "wolfpackcloud"
    influxdb_bucket: str = "robots"

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
