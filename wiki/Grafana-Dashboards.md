# Grafana Dashboards

## Обзор

Система включает два предустановленных дашборда:

1. **Роботы — Обзор** — общий вид флота роботов
2. **Робот — Детали** — детальная информация по конкретному роботу

## Роботы — Обзор

**UID:** `robots-overview`

Общий вид всего флота роботов.

### Панели

| Панель | Тип | Описание |
|--------|-----|----------|
| Всего роботов | Stat | Общее количество зарегистрированных роботов |
| Онлайн | Stat | Роботы в статусе `active` |
| Ожидают привязки | Stat | Роботы в статусе `pending` |
| С ошибками | Stat | Роботы в статусе `error` |
| Список роботов | Table | Таблица со всеми роботами, статусами, IP-адресами |
| Загрузка CPU | Time Series | График CPU по всем роботам |
| Использование RAM | Time Series | График памяти по всем роботам |

### Источники данных

- **PostgreSQL** — список роботов, статусы
- **InfluxDB** — метрики CPU, RAM

### Обновление

Дашборд обновляется каждые **10 секунд**.

---

## Робот — Детали

**UID:** `robot-detail`

Детальный мониторинг выбранного робота.

### Переменные

| Переменная | Тип | Описание |
|------------|-----|----------|
| `$robot` | Query | Выбор робота из списка (тег `robot` в InfluxDB) |

### Панели

#### Stat-панели (верхний ряд)

| Панель | Пороги |
|--------|--------|
| CPU | Зелёный < 70%, Жёлтый 70-90%, Красный > 90% |
| RAM | Зелёный < 70%, Жёлтый 70-85%, Красный > 85% |
| Диск | Зелёный < 80%, Жёлтый 80-90%, Красный > 90% |
| Температура | Зелёный < 60°C, Жёлтый 60-80°C, Красный > 80°C |
| Uptime | — |
| Load Average | Зелёный < 2, Жёлтый 2-5, Красный > 5 |

#### Time Series

| Панель | Описание |
|--------|----------|
| Загрузка CPU | CPU usage в процентах, threshold на 90% |
| Использование RAM | Memory usage в процентах, threshold на 85% |
| Сетевой трафик | Входящий/исходящий трафик (bytes/sec) |
| Температура CPU | График температуры с thresholds |

#### Logs

| Панель | Описание |
|--------|----------|
| Системные логи | Последние 100 записей syslog с робота |

### Источники данных

- **InfluxDB** — все метрики и логи

### Запросы Flux

Пример запроса CPU:

```flux
from(bucket: "robots")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r["_measurement"] == "cpu")
  |> filter(fn: (r) => r["robot"] == "${robot}")
  |> filter(fn: (r) => r["_field"] == "usage_idle")
  |> filter(fn: (r) => r["cpu"] == "cpu-total")
  |> map(fn: (r) => ({r with _value: 100.0 - r._value}))
  |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: false)
```

---

## Создание кастомных дашбордов

### Подключение к InfluxDB

1. Configuration → Data sources → InfluxDB
2. Убедитесь, что источник настроен с Flux query language

### Доступные measurements

| Measurement | Fields | Tags |
|-------------|--------|------|
| cpu | usage_idle, usage_user, usage_system, usage_iowait | cpu, robot, hostname |
| mem | used, available, total, used_percent | robot, hostname |
| disk | used, free, total, used_percent | device, path, robot |
| net | bytes_recv, bytes_sent, packets_recv, packets_sent | interface, robot |
| system | uptime, load1, load5, load15 | robot, hostname |
| temp | temp | sensor, robot |
| syslog | message | level, program, robot |

### Пример нового графика

1. Add panel → Time series
2. Query:

```flux
from(bucket: "robots")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r["_measurement"] == "disk")
  |> filter(fn: (r) => r["_field"] == "used_percent")
  |> filter(fn: (r) => r["path"] == "/")
  |> aggregateWindow(every: v.windowPeriod, fn: mean)
```

---

## Алерты

### Настройка

1. Alerting → Alert rules → New alert rule
2. Выберите папку и группу
3. Настройте условие (например, CPU > 90%)
4. Добавьте contact point (email, Telegram, Slack)

### Примеры правил

**CPU критический:**
```
WHEN avg() OF query(A, 5m, now) IS ABOVE 90
```

**RAM критический:**
```
WHEN avg() OF query(A, 5m, now) IS ABOVE 85
```

**Диск заполнен:**
```
WHEN last() OF query(A, 5m, now) IS ABOVE 90
```

**Температура:**
```
WHEN max() OF query(A, 5m, now) IS ABOVE 80
```

---

## Экспорт/Импорт

### Экспорт дашборда

1. Dashboard settings (⚙️) → JSON Model
2. Скопируйте JSON
3. Или: Dashboard settings → Share → Export

### Импорт

1. Dashboards → Import
2. Вставьте JSON или загрузите файл
3. Выберите datasources
