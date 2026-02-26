# Архитектура

## Общая схема

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              CLOUD / SERVER                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                         Docker Compose Stack                             ││
│  │                                                                         ││
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ││
│  │  │  Nginx   │  │  Grafana │  │ Superset │  │   API    │  │  Redis   │  ││
│  │  │  :80/443 │  │   :3000  │  │  :8088   │  │  :8000   │  │  :6379   │  ││
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘  └──────────┘  ││
│  │       │             │             │             │                       ││
│  │       └─────────────┴─────────────┴─────────────┘                       ││
│  │                              │                                          ││
│  │                    ┌─────────┴─────────┐                                ││
│  │                    │                   │                                ││
│  │              ┌─────┴─────┐       ┌─────┴─────┐                          ││
│  │              │ InfluxDB  │       │ PostgreSQL│                          ││
│  │              │   :8086   │       │   :5432   │                          ││
│  │              └───────────┘       └───────────┘                          ││
│  └─────────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────┘
                                     ▲
                                     │ HTTPS
                                     │
┌────────────────────┐    ┌────────────────────┐    ┌────────────────────┐
│   Robot SBC #1     │    │   Robot SBC #2     │    │   Robot SBC #N     │
│  (OrangePi5/RPi)   │    │  (OrangePi5/RPi)   │    │  (OrangePi5/RPi)   │
│                    │    │                    │    │                    │
│  ┌──────────────┐  │    │  ┌──────────────┐  │    │  ┌──────────────┐  │
│  │   Telegraf   │  │    │  │   Telegraf   │  │    │  │   Telegraf   │  │
│  │    Agent     │  │    │  │    Agent     │  │    │  │    Agent     │  │
│  └──────────────┘  │    │  └──────────────┘  │    │  └──────────────┘  │
└────────────────────┘    └────────────────────┘    └────────────────────┘
```

## Компоненты

### Edge (Робот)

| Компонент | Описание |
|-----------|----------|
| **Telegraf** | Агент сбора метрик. Собирает CPU, RAM, диск, сеть, температуру, логи |
| **install.sh** | Скрипт установки агента и регистрации робота |

### Cloud (Сервер)

| Компонент | Порт | Описание |
|-----------|------|----------|
| **Nginx** | 80/443 | Reverse proxy, TLS терминация |
| **Grafana** | 3000 | Основной веб-интерфейс мониторинга |
| **Superset** | 8088 | BI-аналитика |
| **FastAPI** | 8000 | API привязки роботов |
| **InfluxDB** | 8086 | Time-series БД для метрик и логов |
| **PostgreSQL** | 5432 | Реляционная БД для реестра роботов |
| **Redis** | 6379 | Кэш для Superset |

## Потоки данных

### 1. Регистрация робота

```
Robot                    API                     PostgreSQL
  │                       │                           │
  │  POST /api/pair       │                           │
  │  {hostname, code}     │                           │
  │──────────────────────►│                           │
  │                       │   INSERT robot            │
  │                       │──────────────────────────►│
  │                       │                           │
  │  {robot_id, status}   │                           │
  │◄──────────────────────│                           │
  │                       │                           │
```

### 2. Подтверждение привязки

```
User (Grafana)          API                     PostgreSQL
  │                       │                           │
  │ POST /pair/{code}     │                           │
  │ /confirm              │                           │
  │──────────────────────►│                           │
  │                       │  UPDATE robot             │
  │                       │  status='active'          │
  │                       │──────────────────────────►│
  │                       │                           │
  │  {influxdb_token}     │                           │
  │◄──────────────────────│                           │
  │                       │                           │
```

### 3. Отправка метрик

```
Telegraf                              InfluxDB
  │                                       │
  │  POST /api/v2/write                   │
  │  (cpu, mem, disk, net, logs)          │
  │──────────────────────────────────────►│
  │                                       │
  │  HTTP 204 No Content                  │
  │◄──────────────────────────────────────│
  │                                       │
```

### 4. Визуализация

```
User                   Grafana                 InfluxDB/PostgreSQL
  │                       │                           │
  │  Open Dashboard       │                           │
  │──────────────────────►│                           │
  │                       │   Flux query              │
  │                       │──────────────────────────►│
  │                       │                           │
  │                       │   SQL query               │
  │                       │──────────────────────────►│
  │                       │                           │
  │  Dashboard render     │                           │
  │◄──────────────────────│                           │
```

## Модель данных

### PostgreSQL

```sql
-- Роботы
robots (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255),
  hostname VARCHAR(255),
  ip_address VARCHAR(45),
  architecture ENUM('arm64', 'amd64', 'armhf'),
  status ENUM('pending', 'active', 'inactive', 'error'),
  influxdb_token TEXT,
  created_at TIMESTAMPTZ,
  last_seen_at TIMESTAMPTZ
)

-- Коды привязки
pair_codes (
  id SERIAL PRIMARY KEY,
  code VARCHAR(8) UNIQUE,
  robot_id INTEGER REFERENCES robots(id),
  status ENUM('pending', 'confirmed', 'expired'),
  expires_at TIMESTAMPTZ
)
```

### InfluxDB

```
Bucket: robots

Measurements:
  - cpu (usage_idle, usage_user, usage_system)
  - mem (used_percent, available, total)
  - disk (used_percent, free, total)
  - net (bytes_recv, bytes_sent)
  - temp (temp)
  - system (uptime, load1, load5, load15)
  - syslog (message, level, program)

Tags:
  - robot (имя робота)
  - hostname
  - arch
```

## Безопасность

1. **TLS** — все соединения через HTTPS
2. **Токены** — уникальный токен InfluxDB для каждого робота
3. **8-значный код** — одноразовый код привязки с ограниченным временем жизни (15 минут)
4. **Изоляция** — каждый робот записывает только свои метрики (по тегу `robot`)
