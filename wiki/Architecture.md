# Архитектура

## Общая схема

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              CLOUD / SERVER                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                         Docker Compose Stack                             ││
│  │                                                                         ││
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ││
│  │  │  Client  │  │  Grafana │  │ Superset │  │   API    │  │  Redis   │  ││
│  │  │  :9101   │  │   :9200  │  │  :9300   │  │  :9100   │  │  :6379   │  ││
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
           ▲                                             ▲
           │ HTTPS (User)                                │ HTTPS (Metrics)
           │                                             │
    ┌──────┴──────┐              ┌────────────────────┐  │  ┌────────────────────┐
    │   Browser   │              │   Robot SBC #1     │──┘  │   Robot SBC #N     │
    │   (User)    │              │  (OrangePi5/RPi)   │     │  (OrangePi5/RPi)   │
    └─────────────┘              │  ┌──────────────┐  │     │  ┌──────────────┐  │
                                 │  │   Telegraf   │  │     │  │   Telegraf   │  │
                                 │  │    Agent     │  │     │  │    Agent     │  │
                                 │  └──────────────┘  │     │  └──────────────┘  │
                                 └────────────────────┘     └────────────────────┘
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
| **Client** | 9101 | Веб-приложение (Vue 3) для управления роботами |
| **Grafana** | 9200 | Дашборды мониторинга |
| **Superset** | 9300 | BI-аналитика |
| **FastAPI** | 9100 | REST API (аутентификация, роботы, метрики) |
| **InfluxDB** | 8086 | Time-series БД для метрик и логов |
| **PostgreSQL** | 5432 | Реляционная БД для пользователей и роботов |
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
User (Web App)          API                     PostgreSQL
  │                       │                           │
  │ POST /pair/{code}     │                           │
  │ /confirm              │                           │
  │ Authorization: JWT    │                           │
  │──────────────────────►│                           │
  │                       │  UPDATE robot             │
  │                       │  status='active'          │
  │                       │  owner_id=user.id         │
  │                       │──────────────────────────►│
  │                       │                           │
  │  {influxdb_token}     │                           │
  │◄──────────────────────│                           │
  │                       │                           │
```

Робот привязывается к текущему пользователю (`owner_id`).

### 3. Получение токена (polling)

```
Robot                    API                     PostgreSQL
  │                       │                           │
  │ GET /api/pair/{code}  │                           │
  │ /status               │                           │
  │──────────────────────►│                           │
  │                       │   SELECT status, token    │
  │                       │──────────────────────────►│
  │                       │                           │
  │  {status, token}      │                           │
  │◄──────────────────────│                           │
  │                       │                           │
```

После подтверждения агент получает персональный токен.

### 4. Отправка метрик

```
Telegraf                    API                     InfluxDB
  │                          │                          │
  │  POST /api/metrics       │                          │
  │  Authorization: Bearer   │                          │
  │  {token}                 │                          │
  │─────────────────────────►│                          │
  │                          │   Validate token         │
  │                          │   POST /api/v2/write     │
  │                          │─────────────────────────►│
  │                          │                          │
  │  HTTP 204 No Content     │                          │
  │◄─────────────────────────│                          │
  │                          │                          │
```

Метрики отправляются через API с персональным токеном. API проксирует их в InfluxDB.

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
-- Пользователи
users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  hashed_password VARCHAR(255) NOT NULL,
  name VARCHAR(255) NOT NULL,
  role ENUM('user', 'admin') DEFAULT 'user',
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
)

-- Роботы
robots (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255),
  hostname VARCHAR(255),
  ip_address VARCHAR(45),
  architecture ENUM('arm64', 'amd64', 'armhf'),
  status ENUM('pending', 'active', 'inactive', 'error'),
  influxdb_token TEXT,
  owner_id INTEGER REFERENCES users(id),  -- привязка к пользователю
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
2. **JWT аутентификация** — access/refresh токены для пользователей
3. **Персональные токены роботов** — уникальный токен для каждого робота, выдаётся после подтверждения привязки
4. **API Proxy** — роботы не имеют прямого доступа к InfluxDB, метрики отправляются через API
5. **8-значный код** — одноразовый код привязки с ограниченным временем жизни (15 минут)
6. **Валидация токенов** — API проверяет токен и статус робота перед записью метрик
7. **Отзыв доступа** — при удалении/деактивации робота токен перестаёт работать
8. **Разграничение доступа** — пользователь видит только своих роботов, админ — всех
