# WolfpackCloud Monitoring

![CI](https://img.shields.io/github/actions/workflow/status/ShiWarai/WolfpackCloud-monitoring/ci.yml?label=CI)
![CD](https://img.shields.io/github/actions/workflow/status/ShiWarai/WolfpackCloud-monitoring/cd.yml?label=CD)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Система мониторинга для роботов на одноплатных компьютерах (OrangePi5, Raspberry Pi). Сбор метрик, логов и визуализация в Grafana.

## Быстрый старт

**Сервер:**
```bash
git clone https://github.com/ShiWarai/WolfpackCloud-monitoring.git
cd WolfpackCloud-monitoring
cp .env.example .env
docker compose up -d
```

**Робот:**
```bash
curl -fsSL https://raw.githubusercontent.com/ShiWarai/WolfpackCloud-monitoring/main/agent/install.sh | sudo bash -s -- --server https://YOUR_SERVER_URL
```

После установки:
1. Откройте веб-приложение: http://localhost:9101
2. Зарегистрируйтесь или войдите
3. Введите 8-значный код с робота для привязки

## Порты

| Сервис | Порт | Описание |
|--------|------|----------|
| Client | 9101 | Веб-приложение (Vue 3) |
| API | 9100 | REST API (FastAPI) |
| Grafana | 9200 | Дашборды метрик |
| Superset | 9300 | BI-аналитика |

## Стек

```
Robot: Telegraf Agent
        ↓
Server: Vue 3 → FastAPI → PostgreSQL
                    ↓
              InfluxDB → Grafana
```

## Документация

- [Архитектура](https://github.com/ShiWarai/WolfpackCloud-monitoring/wiki/Architecture)
- [Установка агента](https://github.com/ShiWarai/WolfpackCloud-monitoring/wiki/Installation)
- [Настройка сервера](https://github.com/ShiWarai/WolfpackCloud-monitoring/wiki/Server-Setup)
- [Веб-приложение](https://github.com/ShiWarai/WolfpackCloud-monitoring/wiki/Web-App)
- [API Reference](https://github.com/ShiWarai/WolfpackCloud-monitoring/wiki/API-Reference)

## Лицензия

MIT
