# Устранение неполадок

## Проблемы с агентом (роботом)

### Скрипт установки завершается с ошибкой

**Симптом:** `curl: command not found` или аналогичное

**Решение:**
```bash
# Установите curl
sudo apt update && sudo apt install -y curl

# Или используйте wget
wget -qO- https://raw.githubusercontent.com/ShiWarai/WolfpackCloud-monitoring/main/agent/install.sh | sudo bash -s -- --server YOUR_URL
```

---

### Telegraf не запускается

**Симптом:** `systemctl status telegraf` показывает ошибку

**Диагностика:**
```bash
# Проверьте логи
sudo journalctl -u telegraf -n 50

# Тест конфигурации
sudo telegraf --config /etc/telegraf/telegraf.conf --test
```

**Типичные причины:**
- Ошибка в конфигурации → исправьте `/etc/telegraf/telegraf.conf`
- Нет доступа к сети → проверьте подключение к серверу
- Неверный токен → переустановите агент

---

### Код привязки истёк

**Симптом:** При вводе кода — ошибка "Код истёк"

**Решение:**
```bash
# Переустановите агент для генерации нового кода
sudo /home/ubuntu/WolfpackCloud-monitoring/agent/uninstall.sh
curl -fsSL https://raw.githubusercontent.com/ShiWarai/WolfpackCloud-monitoring/main/agent/install.sh | sudo bash -s -- --server YOUR_URL
```

---

### Метрики не отправляются

**Симптом:** Робот в статусе "активен", но данных нет

**Диагностика:**
```bash
# Проверьте, что Telegraf работает
sudo systemctl status telegraf

# Проверьте отправку
sudo journalctl -u telegraf | grep -i "error\|fail\|write"

# Тест подключения к серверу
curl -I https://your-server:8086/health
```

**Типичные причины:**
- Firewall блокирует порт 8086
- Неверный URL сервера в конфигурации
- Истёк/неверный токен InfluxDB

---

## Проблемы с сервером

### Docker Compose не запускается

**Симптом:** `docker compose up` завершается с ошибкой

**Диагностика:**
```bash
# Проверьте Docker
docker --version
docker compose version

# Проверьте конфигурацию
docker compose config

# Проверьте .env
cat .env
```

**Типичные причины:**
- Отсутствует `.env` файл → `cp .env.example .env`
- Не заданы обязательные переменные → отредактируйте `.env`
- Занят порт → измените порты в `.env` или освободите

---

### API возвращает 500 ошибку

**Симптом:** `/api/*` эндпоинты возвращают Internal Server Error

**Диагностика:**
```bash
# Логи API
docker compose logs api

# Проверьте подключение к БД
docker compose exec api python -c "
from app.database import engine
import asyncio
asyncio.run(engine.connect())
print('OK')
"
```

**Типичные причины:**
- PostgreSQL не запущен или недоступен
- Неверные credentials в DATABASE_URL
- Таблицы не созданы → перезапустите контейнер postgres

---

### Grafana не показывает данные

**Симптом:** Дашборды пустые

**Диагностика:**
1. Configuration → Data sources → InfluxDB → Test
2. Explore → выберите InfluxDB → выполните запрос вручную

**Типичные причины:**
- Неверная конфигурация datasource → проверьте URL и токен
- Нет данных в bucket → проверьте, что Telegraf отправляет
- Неверный time range → увеличьте период

---

### InfluxDB не принимает данные

**Симптом:** Telegraf пишет в лог ошибки авторизации

**Диагностика:**
```bash
# Проверьте токен
docker compose exec influxdb influx auth list

# Проверьте bucket
docker compose exec influxdb influx bucket list
```

**Решение:**
```bash
# Создайте новый токен
docker compose exec influxdb influx auth create \
  --org wolfpackcloud \
  --write-bucket robots \
  --description "Telegraf token"
```

---

### Superset не запускается

**Симптом:** Контейнер перезапускается или недоступен

**Диагностика:**
```bash
docker compose logs superset
```

**Типичные причины:**
- Не задан `SUPERSET_SECRET_KEY` → добавьте в `.env`
- Redis недоступен → проверьте контейнер redis
- Ошибка миграции БД → удалите volume и пересоздайте

---

## Проблемы с сетью

### Робот не может подключиться к серверу

**Диагностика на роботе:**
```bash
# Проверьте DNS
ping your-server.com

# Проверьте порт
nc -zv your-server.com 8086
nc -zv your-server.com 8000

# Проверьте HTTPS
curl -v https://your-server.com/health
```

**Типичные причины:**
- Firewall на сервере → откройте порты 80, 443, 8086
- Неверный DNS → проверьте /etc/hosts или DNS сервер
- Проблемы с сертификатом → используйте HTTP для тестирования

---

### Высокая задержка отправки метрик

**Симптом:** Данные появляются с задержкой > 1 минуты

**Диагностика:**
```bash
# Проверьте интервалы в telegraf.conf
grep -E "interval|flush" /etc/telegraf/telegraf.conf
```

**Решение:**
- Уменьшите `flush_interval` (но не меньше 10s)
- Проверьте качество сетевого соединения
- Проверьте нагрузку на InfluxDB

---

## Восстановление

### Полный сброс сервера

```bash
# Остановка и удаление всего
docker compose down -v

# Удаление образов
docker compose rm -f
docker image prune -a

# Чистый запуск
cp .env.example .env
# Настройте .env
docker compose up -d
```

### Восстановление из бэкапа

**PostgreSQL:**
```bash
docker compose exec -T postgres psql -U monitoring -d monitoring < backup.sql
```

**InfluxDB:**
```bash
docker cp ./influxdb-backup wpc-monitoring-influxdb:/backup
docker compose exec influxdb influx restore /backup
```

---

## Логи и отладка

### Включение debug режима

**API:**
```bash
# В .env
DEBUG=true

# Перезапуск
docker compose restart api
```

**Telegraf:**
```toml
# В telegraf.conf
[agent]
  debug = true
```

**Grafana:**
```bash
# В docker-compose.yml или .env
GF_LOG_LEVEL=debug
```

### Сбор диагностики

```bash
# Создание отчёта
mkdir -p /tmp/diagnostic

# Версии
docker compose version > /tmp/diagnostic/versions.txt
docker --version >> /tmp/diagnostic/versions.txt

# Статус
docker compose ps > /tmp/diagnostic/containers.txt

# Логи (последние 1000 строк)
docker compose logs --tail=1000 > /tmp/diagnostic/logs.txt

# Конфигурация (без секретов)
docker compose config | grep -v PASSWORD > /tmp/diagnostic/config.txt

# Архивирование
tar -czvf diagnostic.tar.gz /tmp/diagnostic/
```
