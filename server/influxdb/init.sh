#!/bin/bash
#
# Скрипт инициализации InfluxDB
# Выполняется после первого запуска для создания дополнительных bucket'ов
# (Основной bucket создаётся автоматически через переменные окружения)
#

set -e

# Ожидаем готовности InfluxDB
echo "Ожидание готовности InfluxDB..."
until influx ping 2>/dev/null; do
    sleep 1
done
echo "InfluxDB готов"

# Переменные из окружения
INFLUX_TOKEN="${DOCKER_INFLUXDB_INIT_ADMIN_TOKEN:-}"
INFLUX_ORG="${DOCKER_INFLUXDB_INIT_ORG:-wolfpackcloud}"

if [ -z "$INFLUX_TOKEN" ]; then
    echo "ОШИБКА: DOCKER_INFLUXDB_INIT_ADMIN_TOKEN не задан"
    exit 1
fi

# Настройка CLI
influx config create \
    --config-name default \
    --host-url http://localhost:8086 \
    --org "$INFLUX_ORG" \
    --token "$INFLUX_TOKEN" \
    --active 2>/dev/null || true

# =============================================================================
# Создание дополнительных bucket'ов
# =============================================================================

echo "Создание дополнительных bucket'ов..."

# Bucket для логов (более короткий retention)
influx bucket create \
    --name logs \
    --org "$INFLUX_ORG" \
    --retention 7d \
    --description "Логи роботов (retention 7 дней)" 2>/dev/null || echo "Bucket 'logs' уже существует"

# Bucket для долгосрочных агрегатов
influx bucket create \
    --name robots_aggregated \
    --org "$INFLUX_ORG" \
    --retention 365d \
    --description "Агрегированные метрики (retention 1 год)" 2>/dev/null || echo "Bucket 'robots_aggregated' уже существует"

# =============================================================================
# Создание задач агрегации (downsampling)
# =============================================================================

echo "Создание задач агрегации..."

# Задача агрегации CPU (каждый час)
influx task create \
    --org "$INFLUX_ORG" \
    --name "Downsample CPU" \
    --every 1h \
    --flux '
option task = {name: "Downsample CPU", every: 1h}

from(bucket: "robots")
    |> range(start: -1h)
    |> filter(fn: (r) => r["_measurement"] == "cpu")
    |> filter(fn: (r) => r["cpu"] == "cpu-total")
    |> filter(fn: (r) => r["_field"] == "usage_idle")
    |> aggregateWindow(every: 5m, fn: mean, createEmpty: false)
    |> to(bucket: "robots_aggregated", org: "wolfpackcloud")
' 2>/dev/null || echo "Задача 'Downsample CPU' уже существует"

# Задача агрегации памяти (каждый час)
influx task create \
    --org "$INFLUX_ORG" \
    --name "Downsample Memory" \
    --every 1h \
    --flux '
option task = {name: "Downsample Memory", every: 1h}

from(bucket: "robots")
    |> range(start: -1h)
    |> filter(fn: (r) => r["_measurement"] == "mem")
    |> filter(fn: (r) => r["_field"] == "used_percent")
    |> aggregateWindow(every: 5m, fn: mean, createEmpty: false)
    |> to(bucket: "robots_aggregated", org: "wolfpackcloud")
' 2>/dev/null || echo "Задача 'Downsample Memory' уже существует"

# =============================================================================
# Создание dashboard-шаблонов (опционально)
# =============================================================================

echo "Инициализация InfluxDB завершена успешно"
