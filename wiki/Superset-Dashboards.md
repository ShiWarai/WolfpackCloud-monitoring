# Superset Dashboards

## Обзор

Apache Superset используется для **BI-аналитики** — ретроспективного анализа данных, ad-hoc SQL запросов и создания отчётов.

В отличие от Grafana (real-time мониторинг), Superset предназначен для ответа на вопросы типа:
- Сколько роботов зарегистрировано за месяц?
- Какой процент роботов в статусе error?
- Распределение роботов по архитектуре?

## Предустановленные assets

При первом запуске автоматически создаются:

### Database Connection

| Имя | Тип | Описание |
|-----|-----|----------|
| WolfpackCloud PostgreSQL | PostgreSQL | Подключение к основной БД |

### Datasets

| Dataset | Таблица | Описание |
|---------|---------|----------|
| robots | `public.robots` | Данные о роботах |
| users | `public.users` | Данные о пользователях |
| pair_codes | `public.pair_codes` | Коды привязки |

### Dashboard: Аналитика роботов

**Slug:** `robots-analytics`

Включает следующие charts:

| Chart | Тип | Описание |
|-------|-----|----------|
| Роботы по статусу | Pie Chart | Распределение по статусам (active, pending, error, inactive) |
| Роботы по архитектуре | Bar Chart | Распределение по архитектуре (arm64, amd64, armhf) |
| Регистрации роботов | Time Series | График регистраций по дням |
| Список роботов | Table | Таблица со всеми роботами |
| Всего пользователей | Big Number | Количество зарегистрированных пользователей |
| Ожидающие привязки | Big Number | Количество активных кодов привязки |

## Доступ

| URL | Логин | Пароль |
|-----|-------|--------|
| http://localhost:9300 | admin | admin |

> ⚠️ **Важно:** Смените пароль после первого входа!

## SQL Lab

Superset включает SQL Lab — интерактивный редактор SQL запросов.

### Примеры запросов

**Роботы онлайн более 7 дней:**

```sql
SELECT name, hostname, status, last_seen_at
FROM robots
WHERE status = 'active'
  AND last_seen_at > NOW() - INTERVAL '7 days'
ORDER BY last_seen_at DESC;
```

**Статистика по статусам:**

```sql
SELECT 
    status,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM robots
GROUP BY status
ORDER BY count DESC;
```

**Роботы без активности более 24 часов:**

```sql
SELECT name, hostname, ip_address, last_seen_at
FROM robots
WHERE status = 'active'
  AND (last_seen_at IS NULL OR last_seen_at < NOW() - INTERVAL '24 hours')
ORDER BY last_seen_at NULLS FIRST;
```

**Регистрации по дням:**

```sql
SELECT 
    DATE_TRUNC('day', created_at) as date,
    COUNT(*) as registrations
FROM robots
GROUP BY DATE_TRUNC('day', created_at)
ORDER BY date DESC
LIMIT 30;
```

## Создание кастомных charts

### 1. Создание Dataset

1. Data → Datasets → + Dataset
2. Выберите database: **WolfpackCloud PostgreSQL**
3. Выберите schema: **public**
4. Выберите table или напишите SQL

### 2. Создание Chart

1. Charts → + Chart
2. Выберите dataset
3. Выберите тип визуализации
4. Настройте metrics и dimensions

### 3. Добавление на Dashboard

1. Откройте dashboard
2. Edit dashboard
3. Charts → перетащите chart на dashboard
4. Save

## Provisioning

Provisioning выполняется контейнером `superset-provision` после старта Superset.

### Отключение provisioning

Если не нужны дефолтные dashboards, можно исключить контейнер:

```bash
docker compose up -d --scale superset-provision=0
```

### Повторный provisioning

```bash
docker compose up superset-provision
```

Скрипт идемпотентен — существующие assets не будут перезаписаны.

### Логи provisioning

```bash
docker compose logs superset-provision
```

## Экспорт/Импорт

### Экспорт dashboard

1. Откройте dashboard
2. ⋮ → Export
3. Скачается ZIP с JSON-конфигурацией

### Импорт

1. Settings → Import Dashboards
2. Загрузите ZIP-файл
3. Настройте маппинг databases

## Alerts & Reports

Superset поддерживает scheduled reports и alerts.

### Настройка

1. Settings → Alerts & Reports
2. + Alert или + Report
3. Настройте schedule (cron)
4. Выберите chart/dashboard
5. Настройте recipients (email)

> Для работы alerts требуется настроенный Celery worker (включен в docker-compose).

## Полезные ссылки

- [Superset Documentation](https://superset.apache.org/docs/intro)
- [Creating Charts](https://superset.apache.org/docs/creating-charts-dashboards/creating-your-first-dashboard)
- [SQL Lab](https://superset.apache.org/docs/using-superset/sql-lab)
