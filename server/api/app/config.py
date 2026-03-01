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
    api_base_url: str

    # Безопасность
    secret_key: str
    pair_code_expiration_minutes: int

    # JWT
    jwt_secret_key: str
    jwt_algorithm: str
    jwt_access_token_expire_minutes: int
    jwt_refresh_token_expire_days: int

    # PostgreSQL
    database_url: str

    # InfluxDB
    influxdb_url: str
    influxdb_token: str
    influxdb_org: str
    influxdb_bucket: str

    # Grafana
    grafana_url: str
    grafana_admin_user: str
    grafana_admin_password: str

    # Superset
    superset_url: str
    superset_admin_username: str
    superset_admin_password: str

    # Администратор WolfpackCloud (создаётся при запуске)
    default_admin_email: str
    default_admin_password: str
    default_admin_name: str

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
