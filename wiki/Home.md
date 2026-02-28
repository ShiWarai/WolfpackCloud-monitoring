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

Grafana: http://localhost:3000 (admin / admin)

### Робот

```bash
curl -fsSL https://raw.githubusercontent.com/ShiWarai/WolfpackCloud-monitoring/main/agent/install.sh | sudo bash -s -- --server YOUR_SERVER_URL
```

Введите 8-значный код в Grafana.

## Навигация

| Страница | Описание |
|----------|----------|
| [[Architecture]] | Архитектура, компоненты, потоки данных |
| [[Installation]] | Установка агента на робота |
| [[Server-Setup]] | Развёртывание сервера |
| [[CI-CD]] | Настройка CI/CD пайплайнов |
| [[API-Reference]] | Документация API |
| [[Grafana-Dashboards]] | Описание дашбордов |
| [[Local-Testing]] | Тестирование без робота |
| [[Troubleshooting]] | Решение проблем |

## Стек

- **Агент**: Telegraf
- **Метрики**: InfluxDB 2.x
- **БД**: PostgreSQL 16
- **Дашборды**: Grafana
- **API**: FastAPI
- **Деплой**: Docker Compose, GitHub Actions
