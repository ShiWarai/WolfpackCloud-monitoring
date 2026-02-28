# Веб-приложение

Веб-приложение на Vue 3 для управления роботами и привязки.

## Доступ

- **URL**: http://localhost:9101 (по умолчанию)
- **Порт**: настраивается через `CLIENT_PORT` в `.env`

## Функционал

### Аутентификация

- Регистрация по email/password
- Вход с JWT токенами (access + refresh)
- Автоматическое обновление токена

### Dashboard

- Общая статистика роботов (всего, активных, ожидающих, с ошибками)
- Быстрые ссылки на Grafana и Superset
- Быстрые действия (привязка робота, список роботов)

### Роботы

- Список роботов пользователя
- Поиск по имени и hostname
- Фильтрация по статусу
- Детальная информация о роботе
- Редактирование и удаление

### Привязка

- Ввод 8-значного кода
- Просмотр информации о роботе перед подтверждением
- Возможность задать имя робота

## Разграничение доступа

| Роль | Права |
|------|-------|
| **user** | Видит только своих роботов |
| **admin** | Видит всех роботов |

При подтверждении привязки робот автоматически привязывается к текущему пользователю.

## Технологии

- **Vue 3** + Composition API
- **TypeScript**
- **Vite** — сборка
- **Vue Router** — маршрутизация с auth guards
- **Pinia** — state management
- **Axios** — HTTP клиент с interceptors
- **Tailwind CSS** — стилизация

## Структура

```
client/
├── src/
│   ├── api/           # Axios client, endpoints
│   ├── components/    # RobotCard, ExternalLinks
│   ├── layouts/       # DefaultLayout
│   ├── pages/         # Login, Register, Dashboard, Robots, Pairing
│   ├── router/        # Vue Router + auth guards
│   ├── stores/        # Pinia stores (auth, robots)
│   └── types/         # TypeScript типы
├── Dockerfile         # Multi-stage build с nginx
└── nginx.conf         # SPA fallback + API proxy
```

## Переменные окружения

В `.env`:

```bash
CLIENT_PORT=9101
GRAFANA_ROOT_URL=http://localhost:9200
SUPERSET_ROOT_URL=http://localhost:9300
```

При сборке Docker образа:

```bash
VITE_API_URL=/api
VITE_GRAFANA_URL=http://localhost:9200
VITE_SUPERSET_URL=http://localhost:9300
```

## Разработка

### Локальный запуск (без Docker)

```bash
cd client
npm install
npm run dev
```

Откроется на http://localhost:5173 с прокси на API.

### Сборка

```bash
make build-client
```

### В составе стека

```bash
make dev
```

Клиент будет доступен на http://localhost:9101
