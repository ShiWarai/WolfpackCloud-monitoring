# -*- coding: utf-8 -*-
"""
Конфигурация Apache Superset для WolfpackCloud Monitoring

Этот файл загружается при старте Superset и настраивает:
- Подключение к PostgreSQL
- Настройки безопасности
- Кэширование через Redis
- Локализацию на русский язык
"""

import os
from datetime import timedelta

# =============================================================================
# Основные настройки
# =============================================================================

# Секретный ключ (ОБЯЗАТЕЛЬНО задать через переменную окружения!)
SECRET_KEY = os.environ.get("SUPERSET_SECRET_KEY", "change-me-in-production")

# Имя приложения
APP_NAME = "WolfpackCloud Analytics"

# =============================================================================
# База данных метаданных Superset
# =============================================================================

# Superset использует PostgreSQL как для метаданных, так и для данных роботов
DATABASE_DB = os.environ.get("DATABASE_DB", "monitoring")
DATABASE_HOST = os.environ.get("DATABASE_HOST", "postgres")
DATABASE_PASSWORD = os.environ.get("DATABASE_PASSWORD", "monitoring")
DATABASE_USER = os.environ.get("DATABASE_USER", "monitoring")
DATABASE_PORT = os.environ.get("DATABASE_PORT", "5432")

SQLALCHEMY_DATABASE_URI = (
    f"postgresql://{DATABASE_USER}:{DATABASE_PASSWORD}@"
    f"{DATABASE_HOST}:{DATABASE_PORT}/{DATABASE_DB}"
)

# =============================================================================
# Redis (кэш и Celery)
# =============================================================================

REDIS_HOST = os.environ.get("REDIS_HOST", "redis")
REDIS_PORT = os.environ.get("REDIS_PORT", "6379")

# Кэширование
CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_DEFAULT_TIMEOUT": 300,
    "CACHE_KEY_PREFIX": "superset_",
    "CACHE_REDIS_HOST": REDIS_HOST,
    "CACHE_REDIS_PORT": int(REDIS_PORT),
    "CACHE_REDIS_DB": 0,
}

DATA_CACHE_CONFIG = CACHE_CONFIG.copy()
DATA_CACHE_CONFIG["CACHE_KEY_PREFIX"] = "superset_data_"
DATA_CACHE_CONFIG["CACHE_DEFAULT_TIMEOUT"] = 86400  # 24 часа

# =============================================================================
# Безопасность
# =============================================================================

# CSRF защита
WTF_CSRF_ENABLED = True
WTF_CSRF_EXEMPT_LIST = ["superset.views.core.log"]
WTF_CSRF_TIME_LIMIT = 60 * 60 * 24 * 365  # 1 год

# CORS (настроить для production)
ENABLE_CORS = True
CORS_OPTIONS = {
    "supports_credentials": True,
    "allow_headers": ["*"],
    "resources": ["*"],
    "origins": ["*"],  # В production ограничить!
}

# Аутентификация
AUTH_TYPE = 1  # AUTH_DB - встроенная аутентификация

# =============================================================================
# Локализация
# =============================================================================

# Доступные языки
LANGUAGES = {
    "ru": {"flag": "ru", "name": "Русский"},
    "en": {"flag": "us", "name": "English"},
}

# Язык по умолчанию
BABEL_DEFAULT_LOCALE = "ru"

# =============================================================================
# Настройки визуализации
# =============================================================================

# Таймзона по умолчанию
DEFAULT_TIMEZONE = "Europe/Moscow"

# Формат даты
D3_FORMAT = {
    "decimal": ",",
    "thousands": " ",
    "grouping": [3],
    "currency": ["", " ₽"],
}

# Количество строк в таблицах
ROW_LIMIT = 50000
DISPLAY_MAX_ROW = 100000

# Таймаут запросов (секунды)
SUPERSET_WEBSERVER_TIMEOUT = 300
SQLLAB_TIMEOUT = 300
SQLLAB_VALIDATION_TIMEOUT = 120

# =============================================================================
# Функции и возможности
# =============================================================================

FEATURE_FLAGS = {
    # SQL Lab
    "ENABLE_TEMPLATE_PROCESSING": True,
    "ENABLE_TEMPLATE_REMOVE_FILTERS": True,
    # Dashboards
    "DASHBOARD_NATIVE_FILTERS": True,
    "DASHBOARD_CROSS_FILTERS": True,
    "DASHBOARD_NATIVE_FILTERS_SET": True,
    # Alerts & Reports
    "ALERT_REPORTS": True,
    # Прочее
    "ENABLE_EXPLORE_DRAG_AND_DROP": True,
    "DRILL_TO_DETAIL": True,
    "VERSIONED_EXPORT": True,
}

# =============================================================================
# Логирование
# =============================================================================

LOG_FORMAT = "%(asctime)s:%(levelname)s:%(name)s:%(message)s"
LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")

ENABLE_TIME_ROTATE = True
TIME_ROTATE_LOG_LEVEL = "INFO"
FILENAME = os.path.join("/app/superset_home", "superset.log")

# =============================================================================
# Celery (фоновые задачи)
# =============================================================================

class CeleryConfig:
    broker_url = f"redis://{REDIS_HOST}:{REDIS_PORT}/1"
    result_backend = f"redis://{REDIS_HOST}:{REDIS_PORT}/2"
    imports = [
        "superset.sql_lab",
        "superset.tasks",
    ]
    task_annotations = {
        "sql_lab.get_sql_results": {"rate_limit": "100/s"},
    }
    task_soft_time_limit = 60 * 5  # 5 минут
    task_time_limit = 60 * 6  # 6 минут (hard limit)

CELERY_CONFIG = CeleryConfig

# =============================================================================
# Базы данных для аналитики (предустановленные)
# =============================================================================

# Эти подключения создаются автоматически при первом запуске
# Для InfluxDB используется FlightSQL или специальный коннектор

# Пример добавления PostgreSQL datasource программно:
# (это можно сделать через API или веб-интерфейс)
#
# from superset.connectors.sqla.models import SqlaTable
# from superset.models.core import Database
#
# db = Database(
#     database_name="WolfpackCloud PostgreSQL",
#     sqlalchemy_uri=SQLALCHEMY_DATABASE_URI,
#     expose_in_sqllab=True,
#     allow_run_async=True,
# )
