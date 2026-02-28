# CI/CD

## Обзор

Проект использует GitHub Actions для автоматизации тестирования и деплоя.

```
Push/PR → CI (lint → test → build) → CD (build → deploy → notify)
```

## Workflows

| Файл | Назначение | Триггеры |
|------|------------|----------|
| `ci.yml` | Линтинг, тесты, сборка | Push/PR в main, dev |
| `cd.yml` | Сборка образов, деплой | После успешного CI, теги v*, ручной запуск |
| `wiki.yml` | Синхронизация Wiki | Push в main, dev (папка wiki/) |

---

## CI Pipeline

### Этапы

1. **Линтинг** (`lint`)
   - Python: `ruff check`, `ruff format`
   - Dockerfile: `hadolint`
   - YAML: `yamllint`
   - Shell: `shellcheck`

2. **Тесты API** (`test-api`)
   - PostgreSQL в service container
   - `pytest` с покрытием

3. **Сборка** (`build`)
   - Docker образ API
   - Проверка `docker compose config`

4. **Интеграционные тесты** (`integration`)
   - Только на push в main/dev
   - Полный стек (PostgreSQL, InfluxDB, API)
   - Тест реальных эндпоинтов

5. **Уведомления** (`notify-telegram-*`)
   - Успех: тихое уведомление
   - Ошибка: уведомление со звуком

---

## CD Pipeline

### Этапы

1. **Сборка и публикация** (`build-and-push`)
   - Multi-arch: `linux/amd64`, `linux/arm64`
   - Публикация в GitHub Container Registry
   - Теги: branch, semver, sha

2. **Деплой** (`deploy`)
   - SSH на production сервер
   - `git pull` + `docker compose pull`
   - Health check
   - Очистка старых образов

3. **Уведомления** (`notify-telegram-*`)

### Триггеры деплоя

| Триггер | Когда |
|---------|-------|
| `workflow_run` | После успешного CI на main |
| `push tags v*` | При создании релиза |
| `workflow_dispatch` | Ручной запуск |

---

## Настройка

### Секреты GitHub

Settings → Secrets and variables → Actions:

| Секрет | Описание |
|--------|----------|
| `PRODUCTION_HOST` | IP или домен сервера |
| `PRODUCTION_USER` | SSH пользователь |
| `PRODUCTION_SSH_KEY` | Приватный SSH ключ |
| `TELEGRAM_TO` | Chat ID для уведомлений |
| `TELEGRAM_TOKEN` | Токен Telegram бота |
| `WIKI_PAT` | Personal Access Token для Wiki |

### Создание SSH ключа

```bash
# Генерация ключа
ssh-keygen -t ed25519 -C "github-deploy" -f deploy_key

# Публичный ключ → на сервер
cat deploy_key.pub >> ~/.ssh/authorized_keys

# Приватный ключ → GitHub Secrets (PRODUCTION_SSH_KEY)
cat deploy_key
```

### Telegram бот

1. Создайте бота через [@BotFather](https://t.me/BotFather)
2. Получите токен → `TELEGRAM_TOKEN`
3. Добавьте бота в чат
4. Получите Chat ID через `https://api.telegram.org/bot<TOKEN>/getUpdates`
5. Chat ID → `TELEGRAM_TO`

---

## Подготовка сервера

### 1. Создание пользователя для деплоя

```bash
# Создать пользователя deploy
sudo adduser deploy

# Добавить в группу docker (после установки Docker)
sudo usermod -aG docker deploy

# Переключиться на пользователя
sudo su - deploy
```

### 2. Настройка SSH ключа

```bash
# Генерация ключа (на сервере, под пользователем deploy)
ssh-keygen -t ed25519 -C "github-deploy"
# Нажать Enter на все вопросы (без пароля)

# Добавить публичный ключ в authorized_keys
cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Показать приватный ключ (скопировать в GitHub Secret PRODUCTION_SSH_KEY)
cat ~/.ssh/id_ed25519
```

### 3. Установка Docker

```bash
# Установка Docker (от root или с sudo)
curl -fsSL https://get.docker.com | sh

# Добавить пользователя deploy в группу docker
sudo usermod -aG docker deploy

# Перелогиниться чтобы применить группу
exit
sudo su - deploy

# Проверить что Docker работает
docker ps
```

### 4. Клонирование репозитория

```bash
# Под пользователем deploy
git clone https://github.com/ShiWarai/WolfpackCloud-monitoring.git ~/app
cd ~/app
```

### 5. Настройка окружения

```bash
cp .env.example .env
```

Отредактировать `.env` — задать реальные пароли:

```bash
nano .env
```

Обязательные переменные:
- `POSTGRES_PASSWORD` — пароль PostgreSQL
- `INFLUXDB_ADMIN_PASSWORD` — пароль InfluxDB
- `INFLUXDB_ADMIN_TOKEN` — токен InfluxDB (минимум 32 символа)
- `SECRET_KEY` — секретный ключ API (минимум 32 символа)

### 6. Первый запуск

```bash
docker compose up -d

# Проверить статус
docker compose ps

# Проверить health
curl http://localhost:8000/health
```

### 7. Проверка доступа

После настройки GitHub Secrets (`PRODUCTION_HOST`, `PRODUCTION_USER`, `PRODUCTION_SSH_KEY`) CD сможет:
1. Подключиться по SSH
2. Выполнить `git pull` для обновления кода
3. Выполнить `docker compose pull` для обновления образов
4. Перезапустить контейнеры

---

### Требования к серверу

- **ОС**: Ubuntu 20.04+ / Debian 11+
- **RAM**: 2+ GB
- **Диск**: 10+ GB
- **Сеть**: публичный IP или домен (для доступа из GitHub Actions)

---

## GitHub Environments (опционально)

Для защиты production с ручным подтверждением:

1. Settings → Environments → New environment
2. Создайте `production`
3. Настройте:
   - Required reviewers
   - Deployment branches: только `main`

---

## Docker образы

Образы публикуются в GitHub Container Registry:

```
ghcr.io/<owner>/wolfpackcloud-monitoring-api:main
ghcr.io/<owner>/wolfpackcloud-monitoring-api:v1.0.0
ghcr.io/<owner>/wolfpackcloud-monitoring-api:sha-abc1234
```

Для использования:

```bash
docker pull ghcr.io/shiwarai/wolfpackcloud-monitoring-api:main
```

---

## Локальный запуск CI

```bash
# Линтинг
ruff check server/api/
ruff format --check server/api/

# Тесты
cd server/api
pytest tests/ -v

# Сборка
docker compose build
docker compose config
```
