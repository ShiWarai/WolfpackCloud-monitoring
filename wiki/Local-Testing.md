# Локальное тестирование

Тестирование системы мониторинга без реального робота.

## Быстрый старт

```bash
# Запуск всего стека + локального агента
./scripts/local-install.sh
```

Скрипт:
1. Создаёт `.env` с тестовыми значениями
2. Запускает Docker Compose стек
3. Запускает Telegraf в контейнере
4. Регистрирует тестового робота
5. Выводит код привязки и URL сервисов

## Доступ к сервисам

После запуска:

| Сервис | URL | Учётные данные |
|--------|-----|----------------|
| Grafana | http://localhost:3000 | admin / admin |
| API | http://localhost:8000/docs | — |
| Superset | http://localhost:8088 | admin / admin |
| InfluxDB | http://localhost:8086 | admin / testpassword123 |
| PostgreSQL | localhost:5432 | monitoring / testpassword123 |

## Подтверждение привязки

1. Откройте http://localhost:3000
2. Войдите как admin/admin
3. Перейдите в Dashboard → "Роботы — Обзор"
4. Найдите тестового робота со статусом "Ожидает"
5. Используйте код из терминала или файла `.local_pair_code`

Или через API:

```bash
# Получить код
cat .local_pair_code

# Подтвердить
curl -X POST "http://localhost:8000/api/pair/$(cat .local_pair_code)/confirm"
```

## Просмотр метрик

После подтверждения привязки:

1. Grafana → Dashboard → "Робот — Детали"
2. В выпадающем списке выберите `local-test-robot`
3. Метрики появятся через 10-30 секунд

## Режимы установки

### Docker (по умолчанию)

```bash
./scripts/local-install.sh --docker
```

Telegraf запускается в Docker контейнере, собирает метрики хоста.

### Native

```bash
./scripts/local-install.sh --native
```

Telegraf устанавливается нативно на хост. Требует sudo.

## Тестирование API

```bash
# Health check
curl http://localhost:8000/health

# Список роботов
curl http://localhost:8000/api/robots

# Регистрация нового робота
curl -X POST http://localhost:8000/api/pair \
  -H "Content-Type: application/json" \
  -d '{"hostname": "test-robot-2", "pair_code": "TEST5678"}'

# Информация о коде
curl http://localhost:8000/api/pair/TEST5678

# Подтверждение
curl -X POST http://localhost:8000/api/pair/TEST5678/confirm
```

## Тестирование отправки метрик

Ручная отправка в InfluxDB:

```bash
# Через curl
curl -X POST "http://localhost:8086/api/v2/write?org=wolfpackcloud&bucket=robots" \
  -H "Authorization: Token test-token-for-development-only" \
  -H "Content-Type: text/plain" \
  --data-binary 'cpu,robot=manual-test,cpu=cpu-total usage_idle=75.5'

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

# Telegraf (локальный контейнер)
docker logs -f wpc-telegraf-local
```

## База данных

### PostgreSQL

```bash
# Подключение
docker compose exec postgres psql -U monitoring -d monitoring

# Запросы
SELECT * FROM robots;
SELECT * FROM pair_codes;
SELECT * FROM robots_view;
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

# Через API
curl -G "http://localhost:8086/api/v2/query" \
  -H "Authorization: Token test-token-for-development-only" \
  -H "Content-Type: application/vnd.flux" \
  --data-urlencode 'org=wolfpackcloud' \
  --data-urlencode 'query=from(bucket:"robots") |> range(start:-1h) |> limit(n:5)'
```

## Удаление

```bash
# Удаление со всеми данными
./scripts/local-uninstall.sh

# Сохранение данных (volumes)
./scripts/local-uninstall.sh --keep-data
```

## Troubleshooting

### Сервисы не запускаются

```bash
# Проверьте порты
sudo lsof -i :3000
sudo lsof -i :8000
sudo lsof -i :8086

# Освободите порты или измените в .env
```

### Telegraf не отправляет данные

```bash
# Проверьте логи Telegraf
docker logs wpc-telegraf-local

# Проверьте конфигурацию
docker exec wpc-telegraf-local cat /etc/telegraf/telegraf.conf

# Тест конфигурации
docker exec wpc-telegraf-local telegraf --test
```

### Нет данных в Grafana

1. Проверьте, что робот в статусе `active`
2. Проверьте datasource в Grafana (Configuration → Data sources)
3. Проверьте запрос в InfluxDB напрямую
4. Подождите 30-60 секунд — данные могут буферизироваться
