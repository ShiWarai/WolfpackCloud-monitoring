# Настройка сервера

## Требования

- Docker Engine 20.10+
- Docker Compose 2.0+
- 2+ GB RAM
- 10+ GB свободного места на диске
- Открытые порты: 80, 443 (или другие по выбору)

## Быстрый старт

### 1. Клонирование репозитория

```bash
git clone https://github.com/ShiWarai/WolfpackCloud-monitoring.git
cd WolfpackCloud-monitoring
```

### 2. Настройка переменных окружения

```bash
cp .env.example .env
```

Отредактируйте `.env`:

```bash
# ОБЯЗАТЕЛЬНЫЕ ПЕРЕМЕННЫЕ

# PostgreSQL
POSTGRES_PASSWORD=your-secure-postgres-password

# InfluxDB
INFLUXDB_ADMIN_PASSWORD=your-secure-influxdb-password
INFLUXDB_ADMIN_TOKEN=your-influxdb-token-min-32-chars

# Безопасность API
SECRET_KEY=your-api-secret-key-min-32-chars
SUPERSET_SECRET_KEY=your-superset-secret-key-min-32-chars

# JWT аутентификация (для веб-приложения)
JWT_SECRET_KEY=your-jwt-secret-key-min-32-chars
JWT_ALGORITHM=HS256
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=30
JWT_REFRESH_TOKEN_EXPIRE_DAYS=7

# ОПЦИОНАЛЬНЫЕ ПЕРЕМЕННЫЕ

# Grafana
GRAFANA_ADMIN_PASSWORD=admin  # Сменить после первого входа!

# Порты
API_PORT=9100
CLIENT_PORT=9101
GRAFANA_PORT=9200
SUPERSET_PORT=9300

# Внешние URL для кнопок в веб-приложении
GRAFANA_ROOT_URL=http://localhost:9200
SUPERSET_ROOT_URL=http://localhost:9300
```

### 3. Запуск

```bash
docker compose up -d
```

### 4. Проверка

```bash
# Статус контейнеров
docker compose ps

# Логи
docker compose logs -f

# Health check
curl http://localhost:8000/health
```

## Доступ к сервисам

| Сервис | URL | Учётные данные |
|--------|-----|----------------|
| Веб-приложение | http://localhost:9101 | Регистрация |
| API Docs | http://localhost:9100/docs | — |
| Grafana | http://localhost:9200 | admin / admin |
| Superset | http://localhost:9300 | admin / admin |
| InfluxDB | http://localhost:8086 | см. .env |

## Production настройка

### TLS/HTTPS

1. Получите SSL сертификат (Let's Encrypt, Cloudflare и др.)
2. Поместите файлы в `server/nginx/ssl/`:
   - `fullchain.pem` — сертификат
   - `privkey.pem` — приватный ключ
3. Раскомментируйте HTTPS блок в `server/nginx/nginx.conf`
4. Перезапустите: `docker compose restart nginx`

### Внешний домен

1. Настройте DNS записи (A или CNAME)
2. Обновите переменные в `.env`:
   ```
   GRAFANA_ROOT_URL=https://monitoring.example.com
   API_BASE_URL=https://monitoring.example.com
   ```
3. Перезапустите сервисы

### Бэкапы

PostgreSQL:
```bash
docker compose exec postgres pg_dump -U monitoring monitoring > backup.sql
```

InfluxDB:
```bash
docker compose exec influxdb influx backup /backup
docker cp wpc-monitoring-influxdb:/backup ./influxdb-backup
```

### Мониторинг самого сервера

Добавьте Telegraf на сервер для мониторинга Docker:

```bash
# Установка Telegraf
curl -fsSL https://repos.influxdata.com/influxdata-archive_compat.key | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/influxdata.gpg
sudo apt install telegraf

# Конфигурация для Docker
sudo tee /etc/telegraf/telegraf.d/docker.conf <<EOF
[[inputs.docker]]
  endpoint = "unix:///var/run/docker.sock"
  gather_services = false
  container_name_include = ["wpc-*"]
EOF

sudo usermod -aG docker telegraf
sudo systemctl restart telegraf
```

## Dev-окружение

Для разработки используйте dev-конфигурацию:

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

Отличия:
- Все порты открыты напрямую (без Nginx)
- Hot reload для API
- Debug режим

## Обновление

```bash
# Остановка
docker compose down

# Получение обновлений
git pull

# Пересборка и запуск
docker compose up -d --build

# Миграции БД (если есть)
docker compose exec api alembic upgrade head
```

## Ansible

Для автоматизации установки агентов на роботы:

```bash
cd agent/ansible

# Настройка inventory
cp inventory.example.yml inventory.yml
# Отредактируйте inventory.yml

# Проверка доступности
ansible -i inventory.yml robots -m ping

# Установка
ansible-playbook -i inventory.yml playbook.yml
```

Пример `inventory.yml`:

```yaml
all:
  vars:
    server_url: "https://monitoring.example.com"
    ansible_user: ubuntu
    ansible_become: true

  children:
    robots:
      hosts:
        robot-01:
          ansible_host: 192.168.1.101
          custom_name: "Складской робот #1"
        robot-02:
          ansible_host: 192.168.1.102
          custom_name: "Складской робот #2"
```

## Troubleshooting

### Контейнер не запускается

```bash
# Проверьте логи
docker compose logs <service_name>

# Проверьте ресурсы
docker stats
```

### API недоступен

```bash
# Проверьте health
curl http://localhost:9100/health

# Проверьте подключение к БД
docker compose exec api python -c "from app.database import engine; print(engine)"
```

### InfluxDB не принимает данные

```bash
# Проверьте токен
docker compose exec influxdb influx auth list

# Тест записи
docker compose exec influxdb influx write \
  --bucket robots \
  --org wolfpackcloud \
  "test,robot=test value=1"
```
