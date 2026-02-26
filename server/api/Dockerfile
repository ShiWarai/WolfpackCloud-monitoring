# syntax=docker/dockerfile:1

# =============================================================================
# WolfpackCloud Monitoring API
# Multi-stage build для production и development
# =============================================================================

# -----------------------------------------------------------------------------
# Base stage - общие зависимости
# -----------------------------------------------------------------------------
FROM python:3.12-slim AS base

WORKDIR /app

# Установка системных зависимостей
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Копирование зависимостей
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# -----------------------------------------------------------------------------
# Development stage - с hot reload
# -----------------------------------------------------------------------------
FROM base AS development

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DEBUG=true

# Установка dev-зависимостей
RUN pip install --no-cache-dir watchfiles

COPY app/ ./app/

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]

# -----------------------------------------------------------------------------
# Production stage - оптимизированный образ
# -----------------------------------------------------------------------------
FROM base AS production

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Создание непривилегированного пользователя
RUN useradd --create-home --shell /bin/bash appuser

COPY app/ ./app/

# Смена владельца
RUN chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
