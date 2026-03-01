# Локальное тестирование

Тестирование системы мониторинга без реального робота.

## Быстрый старт

```bash
# 1. Запуск серверного стека
make dev

# 2. Создание виртуального робота
make agent
```

`make agent` запускает тестового агента (Telegraf в контейнере), который:
1. Регистрируется на сервере
2. **Автоматически подтверждает привязку** (для удобства тестирования)
3. Получает персональный токен
4. Начинает отправлять метрики через `POST /api/metrics`

## Доступ к сервисам

После `make dev` сервисы доступны на портах из `.env`:

| Сервис | Переменная порта | Учётные данные |
|--------|------------------|----------------|
| Web App | `CLIENT_PORT` | см. `.env` (`DEFAULT_ADMIN_EMAIL` / `DEFAULT_ADMIN_PASSWORD`) |
| API | `API_PORT` (+ `/docs` для Swagger) | — |
| Grafana | `GRAFANA_PORT` | см. `.env` (`GRAFANA_ADMIN_USER` / `GRAFANA_ADMIN_PASSWORD`) |
| Superset | `SUPERSET_PORT` | см. `.env` (`SUPERSET_ADMIN_USERNAME` / `SUPERSET_ADMIN_PASSWORD`) |
| InfluxDB | 8086 (внутренний) | см. `.env` |
| PostgreSQL | 5432 (внутренний) | см. `.env` |

## Просмотр метрик

После подтверждения привязки:

1. Grafana → Dashboard → "Робот — Детали"
2. В выпадающем списке выберите `local-test-robot`
3. Метрики появятся через 10-30 секунд

## Управление тестовым агентом

```bash
# Запуск агента
make agent

# Просмотр логов
make agent-logs

# Остановка агента
make agent-stop
```

Агент запускается в Docker контейнере и собирает метрики хоста.

## Тестирование API

Замените `$API_URL` на адрес API из `.env` (например, `http://localhost:$API_PORT`).

```bash
# Health check
curl $API_URL/health

# Получение JWT токена (вход)
# Замените email/password на значения из .env
TOKEN=$(curl -s -X POST $API_URL/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "$DEFAULT_ADMIN_EMAIL", "password": "$DEFAULT_ADMIN_PASSWORD"}' | jq -r '.access_token')

# Список роботов (требует JWT)
curl -H "Authorization: Bearer $TOKEN" $API_URL/api/robots

# Регистрация нового робота (от агента, без JWT)
curl -X POST $API_URL/api/pair \
  -H "Content-Type: application/json" \
  -d '{"hostname": "test-robot-2", "pair_code": "TEST5678"}'

# Информация о коде
curl $API_URL/api/pair/TEST5678

# Статус привязки (polling)
curl $API_URL/api/pair/TEST5678/status

# Подтверждение (требует JWT)
curl -X POST -H "Authorization: Bearer $TOKEN" $API_URL/api/pair/TEST5678/confirm

# Статус после подтверждения (теперь с токеном)
curl $API_URL/api/pair/TEST5678/status
```

## Тестирование отправки метрик

### Через API (рекомендуемый способ)

```bash
# Получить токен робота
ROBOT_TOKEN=$(cat .local_robot_token)

# Отправить метрику через API
curl -X POST "$API_URL/api/metrics" \
  -H "Authorization: Bearer $ROBOT_TOKEN" \
  -H "Content-Type: text/plain" \
  --data-binary 'cpu,robot=manual-test,cpu=cpu-total usage_idle=75.5'
```

### Напрямую в InfluxDB (только для отладки)

```bash
# Через influx CLI в контейнере
docker compose exec influxdb influx write \
  --bucket robots \
  --org wolfpackcloud \
  'cpu,robot=manual-test,cpu=cpu-total usage_idle=65.0'
```

## Логи

```bash
# Все сервисы
docker compose logs -f

# Конкретный сервис
docker compose logs -f api
docker compose logs -f grafana
docker compose logs -f influxdb

# Telegraf (тестовый агент)
make agent-logs
```

## База данных

### PostgreSQL

```bash
# Подключение
docker compose exec postgres psql -U monitoring -d monitoring

# Запросы
SELECT * FROM robots;
SELECT * FROM pair_codes;
```

### InfluxDB

```bash
# CLI
docker compose exec influxdb influx query '
from(bucket: "robots")
  |> range(start: -1h)
  |> filter(fn: (r) => r["_measurement"] == "cpu")
  |> limit(n: 10)
'
```

## Удаление

```bash
# Остановить агента
make agent-stop

# Очистить данные (метрики и роботы)
make clean-data

# Полная остановка стека
make down
```

## Troubleshooting

### Сервисы не запускаются

```bash
# Проверьте, не заняты ли порты из .env
# Освободите порты или измените значения в .env
docker compose ps
docker compose logs
```

### Telegraf не отправляет данные

```bash
# Проверьте логи Telegraf
make agent-logs

# Или напрямую через Docker
docker logs wpc-monitoring-agent

# Проверьте конфигурацию
docker exec wpc-monitoring-agent cat /etc/telegraf/telegraf.conf

# Тест конфигурации
docker exec wpc-monitoring-agent telegraf --test
```

### Нет данных в Grafana

1. Проверьте, что робот в статусе `active`
2. Проверьте datasource в Grafana (Configuration → Data sources)
3. Проверьте запрос в InfluxDB напрямую
4. Подождите 30-60 секунд — данные могут буферизироваться
