import os

from flask_caching.backends.filesystemcache import FileSystemCache

# ---- Metadata DB (PostgreSQL) ------------------------------------------------
DATABASE_DIALECT = os.getenv("DATABASE_DIALECT", "postgresql")
DATABASE_USER = os.getenv("DATABASE_USER", "monitoring")
DATABASE_PASSWORD = os.getenv("DATABASE_PASSWORD", "monitoring")
DATABASE_HOST = os.getenv("DATABASE_HOST", "postgres")
DATABASE_PORT = os.getenv("DATABASE_PORT", "5432")
DATABASE_DB = os.getenv("DATABASE_DB", "monitoring")

SQLALCHEMY_DATABASE_URI = (
    f"{DATABASE_DIALECT}://"
    f"{DATABASE_USER}:{DATABASE_PASSWORD}@"
    f"{DATABASE_HOST}:{DATABASE_PORT}/{DATABASE_DB}"
)

# ---- Secret key --------------------------------------------------------------
SECRET_KEY = os.environ.get("SUPERSET_SECRET_KEY", "change-me-in-production")

# ---- App name ----------------------------------------------------------------
APP_NAME = "WolfpackCloud Analytics"

# ---- Redis -------------------------------------------------------------------
REDIS_HOST = os.getenv("REDIS_HOST", "redis")
REDIS_PORT = os.getenv("REDIS_PORT", "6379")
REDIS_CELERY_DB = os.getenv("REDIS_CELERY_DB", "0")
REDIS_RESULTS_DB = os.getenv("REDIS_RESULTS_DB", "1")

# ---- Cache -------------------------------------------------------------------
RESULTS_BACKEND = FileSystemCache("/app/superset_home/sqllab")

CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_DEFAULT_TIMEOUT": 300,
    "CACHE_KEY_PREFIX": "superset_",
    "CACHE_REDIS_HOST": REDIS_HOST,
    "CACHE_REDIS_PORT": REDIS_PORT,
    "CACHE_REDIS_DB": REDIS_RESULTS_DB,
}
DATA_CACHE_CONFIG = {
    **CACHE_CONFIG,
    "CACHE_KEY_PREFIX": "superset_data_",
    "CACHE_DEFAULT_TIMEOUT": 86400,
}

# ---- Celery ------------------------------------------------------------------
class CeleryConfig:
    broker_url = f"redis://{REDIS_HOST}:{REDIS_PORT}/{REDIS_CELERY_DB}"
    imports = (
        "superset.sql_lab",
        "superset.tasks.scheduler",
        "superset.tasks.thumbnails",
        "superset.tasks.cache",
    )
    result_backend = f"redis://{REDIS_HOST}:{REDIS_PORT}/{REDIS_RESULTS_DB}"
    worker_prefetch_multiplier = 1
    task_acks_late = False

CELERY_CONFIG = CeleryConfig

# ---- Security ----------------------------------------------------------------
WTF_CSRF_ENABLED = True
AUTH_TYPE = 1  # AUTH_DB
FAB_ADD_SECURITY_API = True  # REST API для создания пользователей

# ---- Localisation ------------------------------------------------------------
LANGUAGES = {
    "ru": {"flag": "ru", "name": "Русский"},
    "en": {"flag": "us", "name": "English"},
}
BABEL_DEFAULT_LOCALE = "ru"

# ---- Viz defaults ------------------------------------------------------------
DEFAULT_TIMEZONE = "Europe/Moscow"
ROW_LIMIT = 50_000
DISPLAY_MAX_ROW = 100_000
SUPERSET_WEBSERVER_TIMEOUT = 300
SQLLAB_TIMEOUT = 300
SQLLAB_CTAS_NO_LIMIT = True

# ---- Feature flags -----------------------------------------------------------
FEATURE_FLAGS = {
    "ENABLE_TEMPLATE_PROCESSING": True,
    "DASHBOARD_NATIVE_FILTERS": True,
    "DASHBOARD_CROSS_FILTERS": True,
    "ENABLE_EXPLORE_DRAG_AND_DROP": True,
    "DRILL_TO_DETAIL": True,
    "ALERT_REPORTS": True,
}
ALERT_REPORTS_NOTIFICATION_DRY_RUN = True

# ---- Logging -----------------------------------------------------------------
LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")
