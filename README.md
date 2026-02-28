# WolfpackCloud Monitoring

![CI](https://img.shields.io/github/actions/workflow/status/ShiWarai/WolfpackCloud-monitoring/ci.yml?label=CI)
![CD](https://img.shields.io/github/actions/workflow/status/ShiWarai/WolfpackCloud-monitoring/cd.yml?label=CD)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Система мониторинга для роботов на одноплатных компьютерах (OrangePi5, Raspberry Pi). Сбор метрик, логов и визуализация в Grafana.

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

Введите 8-значный код в Grafana для привязки.

## Стек

| Компонент | Технология |
|-----------|------------|
| Агент | Telegraf |
| Метрики | InfluxDB 2.x |
| Дашборды | Grafana |
| API | FastAPI |
| БД | PostgreSQL |

## Документация

Подробная документация в [Wiki](https://github.com/ShiWarai/WolfpackCloud-monitoring/wiki):

- [Архитектура](https://github.com/ShiWarai/WolfpackCloud-monitoring/wiki/Architecture)
- [Установка агента](https://github.com/ShiWarai/WolfpackCloud-monitoring/wiki/Installation)
- [Настройка сервера](https://github.com/ShiWarai/WolfpackCloud-monitoring/wiki/Server-Setup)
- [CI/CD](https://github.com/ShiWarai/WolfpackCloud-monitoring/wiki/CI-CD)
- [API Reference](https://github.com/ShiWarai/WolfpackCloud-monitoring/wiki/API-Reference)

## Лицензия

MIT
