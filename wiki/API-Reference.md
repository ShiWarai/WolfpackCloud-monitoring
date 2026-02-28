# API Reference

Полная документация API доступна по адресу `/docs` (Swagger UI) или `/redoc` (ReDoc).

## Base URL

```
http://localhost:8000
```

## Аутентификация

### Для роботов (отправка метрик)

Эндпоинт `POST /api/metrics` требует заголовок `Authorization`:

```
Authorization: Bearer {robot_token}
```

Токен выдаётся роботу после подтверждения привязки через `GET /api/pair/{code}/status`.

### Для пользователей

Остальные эндпоинты не требуют аутентификации. В production рекомендуется добавить API keys или JWT для управления роботами.

---

## Привязка роботов

### POST /api/pair

Регистрация робота в системе (вызывается агентом).

**Request:**

```json
{
  "hostname": "robot-01",
  "name": "Складской робот #1",
  "ip_address": "192.168.1.101",
  "architecture": "arm64",
  "pair_code": "ABCD1234"
}
```

| Поле | Тип | Обязательно | Описание |
|------|-----|-------------|----------|
| hostname | string | да | Hostname устройства |
| name | string | нет | Пользовательское имя (по умолчанию = hostname) |
| ip_address | string | нет | IP-адрес |
| architecture | enum | нет | `arm64`, `amd64`, `armhf` (по умолчанию arm64) |
| pair_code | string | да | 8-значный код (A-Z, 0-9, без O,0,I,1,L) |

**Response (201 Created):**

```json
{
  "robot_id": 1,
  "pair_code": "ABCD1234",
  "status": "pending",
  "expires_at": "2024-02-01T12:15:00Z",
  "influxdb_token": null,
  "message": "Робот зарегистрирован. Код привязки: ABCD1234. Подтвердите привязку..."
}
```

**Errors:**
- `409 Conflict` — код уже используется

---

### GET /api/pair/{code}

Получение информации о коде привязки.

**Response (200 OK):**

```json
{
  "code": "ABCD1234",
  "status": "pending",
  "created_at": "2024-02-01T12:00:00Z",
  "expires_at": "2024-02-01T12:15:00Z",
  "robot": {
    "id": 1,
    "name": "Складской робот #1",
    "hostname": "robot-01",
    "ip_address": "192.168.1.101",
    "architecture": "arm64",
    "status": "pending",
    "created_at": "2024-02-01T12:00:00Z",
    "updated_at": "2024-02-01T12:00:00Z"
  }
}
```

**Errors:**
- `404 Not Found` — код не найден

---

### POST /api/pair/{code}/confirm

Подтверждение привязки (вызывается пользователем из UI).

**Request:**

```json
{
  "robot_name": "Новое имя робота"
}
```

| Поле | Тип | Обязательно | Описание |
|------|-----|-------------|----------|
| robot_name | string | нет | Новое имя робота |

**Response (200 OK):**

```json
{
  "robot_id": 1,
  "status": "active",
  "influxdb_token": "abc123...",
  "message": "Робот 'Складской робот #1' успешно привязан и готов к мониторингу."
}
```

**Errors:**
- `400 Bad Request` — код уже подтверждён
- `404 Not Found` — код не найден
- `410 Gone` — код истёк

---

### GET /api/pair/{code}/status

Статус привязки (polling). Вызывается агентом после регистрации для получения токена.

**Response (200 OK) — pending:**

```json
{
  "status": "pending",
  "robot_id": 1,
  "robot_token": null,
  "api_url": "http://server:8000/api/metrics",
  "message": "Ожидание подтверждения пользователем."
}
```

**Response (200 OK) — confirmed:**

```json
{
  "status": "confirmed",
  "robot_id": 1,
  "robot_token": "abc123...",
  "api_url": "http://server:8000/api/metrics",
  "message": "Привязка подтверждена. Используйте токен для отправки метрик."
}
```

**Response (200 OK) — expired:**

```json
{
  "status": "expired",
  "robot_id": null,
  "robot_token": null,
  "api_url": "http://server:8000",
  "message": "Срок действия кода истёк. Зарегистрируйтесь заново."
}
```

**Errors:**
- `404 Not Found` — код не найден

---

## Метрики

### POST /api/metrics

Приём метрик от робота. Метрики проксируются в InfluxDB.

**Headers:**

```
Authorization: Bearer {robot_token}
Content-Type: text/plain; charset=utf-8
```

**Request Body:** InfluxDB Line Protocol

```
cpu,robot=robot-01,cpu=cpu-total usage_idle=98.5 1709134800000000000
mem,robot=robot-01 used_percent=45.2 1709134800000000000
```

**Response:** `204 No Content`

**Errors:**
- `400 Bad Request` — пустое тело или невалидные данные
- `401 Unauthorized` — невалидный или отсутствующий токен
- `403 Forbidden` — робот не активен
- `502 Bad Gateway` — ошибка записи в InfluxDB

---

## Управление роботами

### GET /api/robots

Список всех роботов.

**Query Parameters:**

| Параметр | Тип | Описание |
|----------|-----|----------|
| status | enum | Фильтр: `pending`, `active`, `inactive`, `error` |
| search | string | Поиск по имени/hostname |
| skip | int | Пропустить N записей (пагинация) |
| limit | int | Максимум записей (1-100, по умолчанию 50) |

**Response (200 OK):**

```json
{
  "robots": [
    {
      "id": 1,
      "name": "Складской робот #1",
      "hostname": "robot-01",
      "ip_address": "192.168.1.101",
      "architecture": "arm64",
      "status": "active",
      "description": null,
      "created_at": "2024-02-01T12:00:00Z",
      "updated_at": "2024-02-01T12:05:00Z",
      "last_seen_at": "2024-02-01T14:30:00Z"
    }
  ],
  "total": 1
}
```

---

### GET /api/robots/{robot_id}

Информация о роботе.

**Response (200 OK):**

```json
{
  "id": 1,
  "name": "Складской робот #1",
  "hostname": "robot-01",
  "ip_address": "192.168.1.101",
  "architecture": "arm64",
  "status": "active",
  "description": null,
  "influxdb_token": "abc123...",
  "created_at": "2024-02-01T12:00:00Z",
  "updated_at": "2024-02-01T12:05:00Z",
  "last_seen_at": "2024-02-01T14:30:00Z"
}
```

---

### PATCH /api/robots/{robot_id}

Обновление робота.

**Request:**

```json
{
  "name": "Новое имя",
  "description": "Описание",
  "status": "inactive"
}
```

**Response (200 OK):** Обновлённый объект робота.

---

### DELETE /api/robots/{robot_id}

Удаление робота.

**Response:** `204 No Content`

---

### POST /api/robots/{robot_id}/heartbeat

Heartbeat (обновление времени последней активности).

**Response (200 OK):** Объект робота с обновлённым `last_seen_at`.

---

## Health Check

### GET /health

Проверка работоспособности.

**Response (200 OK):**

```json
{
  "status": "ok",
  "version": "0.1.0",
  "database": "connected",
  "influxdb": "connected"
}
```

---

## Коды ошибок

| Код | Описание |
|-----|----------|
| 400 | Неверный запрос |
| 404 | Ресурс не найден |
| 409 | Конфликт (дубликат) |
| 410 | Ресурс более недоступен (истёк) |
| 500 | Внутренняя ошибка сервера |

**Формат ошибки:**

```json
{
  "detail": "Описание ошибки",
  "error_code": "OPTIONAL_ERROR_CODE"
}
```
