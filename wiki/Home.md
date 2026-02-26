# WolfpackCloud Monitoring

Добро пожаловать в Wiki подсистемы мониторинга WolfpackCloud!

## Обзор

WolfpackCloud Monitoring — подсистема для сбора метрик и логов с одноплатных компьютеров мобильных роботов (OrangePi5, Raspberry Pi) и их визуализации в централизованной панели управления.

## Быстрый старт

### Сервер (5 минут)

```bash
git clone https://github.com/ShiWarai/WolfpackCloud-monitoring.git
cd WolfpackCloud-monitoring
cp .env.example .env
# Отредактируйте .env
docker compose up -d
```

Откройте Grafana: http://localhost:3000 (admin / admin)

### Робот (2 минуты)

```bash
curl -fsSL https://raw.githubusercontent.com/ShiWarai/WolfpackCloud-monitoring/main/agent/install.sh | bash -s -- --server YOUR_SERVER_URL
```

Введите 8-значный код в панели Grafana.

## Навигация

| Страница | Описание |
|----------|----------|
| [[Architecture]] | Архитектура системы, компоненты, потоки данных |
| [[Installation]] | Установка агента на робота |
| [[Server-Setup]] | Развёртывание серверной части |
| [[Deployment-Options]] | Варианты деплоя (GitHub, облако, свой сервер) |
| [[API-Reference]] | Документация API привязки роботов |
| [[Grafana-Dashboards]] | Описание дашбордов |
| [[Local-Testing]] | Тестирование без реального робота |
| [[Troubleshooting]] | Решение типичных проблем |

## Технологический стек

- **Агент**: Telegraf
- **Базы данных**: InfluxDB 2.x, PostgreSQL 16
- **Веб-интерфейс**: Grafana OSS 11
- **BI-аналитика**: Apache Superset
- **API**: FastAPI + SQLAlchemy
- **Контейнеризация**: Docker Compose

## Связанные проекты

- [WolfpackCloud](https://github.com/ShiWarai/WolfpackCloud) — основная платформа управления роботами
