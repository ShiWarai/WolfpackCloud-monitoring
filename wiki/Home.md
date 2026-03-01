# WolfpackCloud Monitoring

Система мониторинга для роботов на одноплатных компьютерах (OrangePi5, Raspberry Pi).

## Быстрый старт

### Сервер

```bash
git clone https://github.com/ShiWarai/WolfpackCloud-monitoring.git
cd WolfpackCloud-monitoring
cp .env.example .env
docker compose up -d
```

### Порты

Порты сервисов настраиваются в `.env`. См. переменные `CLIENT_PORT`, `API_PORT`, `GRAFANA_PORT`, `SUPERSET_PORT`.

### Роботы (на каждом)

```bash
curl -fsSL https://raw.githubusercontent.com/ShiWarai/WolfpackCloud-monitoring/main/agent/install.sh | sudo bash -s -- --server YOUR_SERVER_URL
```

После установки на каждом роботе:
1. Откройте веб-приложение (URL и порт см. в `.env`)
2. Войдите под администратором (учётные данные в `.env`)
3. Перейдите в раздел "Привязка" и введите 8-значный код

## Навигация

| Страница | Описание |
|----------|----------|
| [[Architecture]] | Архитектура, компоненты, потоки данных |
| [[Web-App]] | Веб-приложение (Vue 3) |
| [[Installation]] | Установка агента на робота |
| [[Server-Setup]] | Развёртывание сервера |
| [[CI-CD]] | Настройка CI/CD пайплайнов |
| [[API-Reference]] | Документация API |
| [[Grafana-Dashboards]] | Дашборды мониторинга (real-time) |
| [[Superset-Dashboards]] | Дашборды аналитики (BI) |
| [[Local-Testing]] | Тестирование без робота |
| [[Troubleshooting]] | Решение проблем |

## Стек

- **Веб**: Vue 3 + TypeScript + Tailwind CSS
- **API**: FastAPI (Python)
- **Агент**: Telegraf
- **Метрики**: InfluxDB 2.x
- **БД**: PostgreSQL 16
- **Мониторинг**: Grafana
- **Аналитика**: Apache Superset
- **Деплой**: Docker Compose, GitHub Actions
