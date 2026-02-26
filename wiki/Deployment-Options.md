# Варианты деплоя

## Обзор

Проект поддерживает несколько вариантов деплоя в зависимости от ваших потребностей и доступных ресурсов.

| Вариант | Стоимость | Сложность | Подходит для |
|---------|-----------|-----------|--------------|
| GitHub Actions (CI) | Бесплатно | Низкая | Тестирование, проверка сборки |
| GitHub Codespaces | Бесплатный tier | Низкая | Разработка, демонстрации |
| Render / Railway | Бесплатный tier | Средняя | Development, небольшие проекты |
| Собственный сервер | Зависит | Высокая | Staging, Production |

---

## 1. GitHub Actions (без внешнего сервера)

Самый простой вариант — использовать GitHub Actions runner для запуска и тестирования стека. Это уже настроено в CI workflow.

### Что происходит при пуше в `dev`:

1. Линтинг кода (ruff, hadolint, yamllint)
2. Unit-тесты API
3. Сборка Docker образов
4. Запуск интеграционных тестов:
   - `docker compose up` на runner
   - Проверка health endpoint
   - Тестирование API эндпоинтов
5. Публикация образов в GitHub Container Registry

### Преимущества:
- Не нужен собственный сервер
- Полностью автоматизировано
- Бесплатно для публичных репозиториев

### Ограничения:
- Окружение живёт только во время выполнения workflow
- Нет постоянного URL для доступа
- Ограничение по времени выполнения (6 часов)

### Как использовать:

```yaml
# В .github/workflows/ci.yml уже настроено
integration:
  name: Интеграционные тесты
  runs-on: ubuntu-latest
  if: github.ref == 'refs/heads/main' || github.ref == 'refs/heads/dev'
  
  steps:
    - name: Запуск стека
      run: |
        docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d
        sleep 30
        curl -f http://localhost:8000/health
```

---

## 2. GitHub Codespaces

Полноценное облачное dev-окружение с VS Code в браузере.

### Настройка:

1. Создайте файл `.devcontainer/devcontainer.json`:

```json
{
  "name": "WolfpackCloud Monitoring",
  "dockerComposeFile": ["../docker-compose.yml", "../docker-compose.dev.yml"],
  "service": "api",
  "workspaceFolder": "/workspace",
  "forwardPorts": [3000, 8000, 8086, 8088],
  "postCreateCommand": "pip install -r server/api/requirements.txt",
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-python.python",
        "ms-azuretools.vscode-docker"
      ]
    }
  }
}
```

2. Откройте репозиторий в Codespaces (кнопка "Code" → "Codespaces")
3. Все сервисы автоматически запустятся
4. Получите preview URL для Grafana, API и др.

### Преимущества:
- Полноценное dev-окружение
- Доступ через браузер
- Бесплатный tier: 60 часов/месяц

### Ограничения:
- Ограничение по времени
- Данные не сохраняются между сессиями (без доп. настройки)

---

## 3. Бесплатные облачные платформы

### Render

[Render](https://render.com) предлагает бесплатный tier для Docker-сервисов.

**Настройка:**

1. Подключите GitHub репозиторий
2. Создайте `render.yaml`:

```yaml
services:
  - type: web
    name: wpc-monitoring-api
    env: docker
    dockerfilePath: ./server/api/Dockerfile
    dockerContext: ./server/api
    envVars:
      - key: DATABASE_URL
        fromDatabase:
          name: wpc-postgres
          property: connectionString
    healthCheckPath: /health

databases:
  - name: wpc-postgres
    databaseName: monitoring
    user: monitoring
```

3. Render автоматически деплоит при пуше

**Ограничения бесплатного tier:**
- Сервисы "засыпают" после 15 минут неактивности
- 750 часов/месяц
- Нет поддержки Docker Compose (только отдельные сервисы)

### Railway

[Railway](https://railway.app) — похожий сервис с поддержкой Docker Compose.

**Настройка:**

1. Установите Railway CLI: `npm i -g @railway/cli`
2. Авторизуйтесь: `railway login`
3. Инициализируйте проект: `railway init`
4. Деплой: `railway up`

**Бесплатный tier:**
- $5 кредитов/месяц
- Автодеплой из GitHub

### Fly.io

[Fly.io](https://fly.io) — хорош для контейнеров с глобальным распределением.

```bash
# Установка
curl -L https://fly.io/install.sh | sh

# Авторизация
fly auth login

# Деплой
fly launch
fly deploy
```

**Бесплатный tier:**
- 3 shared-cpu VMs
- 160GB исходящего трафика

---

## 4. Собственный сервер

Для staging и production рекомендуется собственный сервер.

### Требуемые GitHub Secrets:

| Окружение | Секреты |
|-----------|---------|
| Development | `DEV_HOST`, `DEV_USER`, `DEV_SSH_KEY` |
| Staging | `STAGING_HOST`, `STAGING_USER`, `STAGING_SSH_KEY` |
| Production | `PRODUCTION_HOST`, `PRODUCTION_USER`, `PRODUCTION_SSH_KEY` |

### Настройка секретов:

1. Settings → Secrets and variables → Actions
2. New repository secret
3. Добавьте секреты для каждого окружения

### Подготовка сервера:

```bash
# На сервере
sudo apt update
sudo apt install -y docker.io docker-compose-plugin git

# Добавьте пользователя в группу docker
sudo usermod -aG docker $USER

# Клонируйте репозиторий
git clone https://github.com/ShiWarai/WolfpackCloud-monitoring.git /opt/wolfpackcloud-monitoring
cd /opt/wolfpackcloud-monitoring

# Настройте окружение
cp .env.example .env
# Отредактируйте .env

# Первый запуск
docker compose up -d
```

### SSH-ключ для CI/CD:

```bash
# На локальной машине
ssh-keygen -t ed25519 -C "github-actions" -f ~/.ssh/github-actions

# Скопируйте публичный ключ на сервер
ssh-copy-id -i ~/.ssh/github-actions.pub user@server

# Приватный ключ добавьте в GitHub Secrets
cat ~/.ssh/github-actions
```

---

## 5. Рекомендуемая стратегия

### Для разработки (dev ветка):
- **GitHub Actions** — автоматические тесты при каждом пуше
- **GitHub Codespaces** — для ручной разработки и отладки

### Для staging (main ветка):
- **Render/Railway** (бесплатно) или **собственный сервер**
- Автодеплой при мерже в main

### Для production (теги v*):
- **Собственный сервер** с ручным подтверждением деплоя
- GitHub Environments с required reviewers

### Пример workflow:

```
feature/* → dev (PR)
    ↓
  CI: lint, test, build
    ↓
dev → main (PR)
    ↓
  Deploy: staging
    ↓
v1.0.0 (tag)
    ↓
  Deploy: production (manual approval)
```

---

## Настройка GitHub Environments

Для защиты production:

1. Settings → Environments → New environment
2. Создайте: `development`, `staging`, `production`
3. Для `production`:
   - Required reviewers: добавьте себя
   - Wait timer: 5 минут (опционально)
   - Deployment branches: только `main` и теги

---

## Полезные команды

```bash
# Локальный запуск для тестирования
./scripts/local-install.sh

# Проверка конфигурации
docker compose config

# Просмотр логов CI
gh run list
gh run view <run-id> --log
```
