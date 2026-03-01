# WolfpackCloud Monitoring

![CI](https://img.shields.io/github/actions/workflow/status/ShiWarai/WolfpackCloud-monitoring/ci.yml?label=CI)
![CD](https://img.shields.io/github/actions/workflow/status/ShiWarai/WolfpackCloud-monitoring/cd.yml?label=CD)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Система мониторинга для роботов на одноплатных компьютерах (OrangePi5, Raspberry Pi). Сбор метрик, логов и визуализация в Grafana.

<img width="2552" height="1352" alt="image" src="https://github.com/user-attachments/assets/b4381d02-a552-4268-b025-5cab83df45ff" />

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
1. Откройте веб-приложение (URL и порты см. в `.env`)
2. Войдите (учётные данные в `.env`)
3. Введите 8-значный код с робота для привязки

## Сервисы

| Сервис | Переменная порта | Описание |
|--------|------------------|----------|
| Client | `CLIENT_PORT` | Веб-приложение (Vue 3) |
| API | `API_PORT` | REST API (FastAPI) |
| Grafana | `GRAFANA_PORT` | Дашборды метрик |
| Superset | `SUPERSET_PORT` | BI-аналитика |

Все порты и учётные данные настраиваются в `.env`.

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
