# Установка агента на робота

## Требования

- Linux (Debian/Ubuntu, Raspberry Pi OS, Armbian)
- Архитектура: ARM64 (aarch64), AMD64 (x86_64), ARMv7 (armhf)
- Доступ в интернет
- Права root (sudo)

## Быстрая установка

### Однострочная команда

```bash
curl -fsSL https://raw.githubusercontent.com/ShiWarai/WolfpackCloud-monitoring/main/agent/install.sh | sudo bash -s -- --server https://monitoring.example.com
```

Замените `https://monitoring.example.com` на URL вашего сервера мониторинга.

### С указанием имени робота

```bash
curl -fsSL https://raw.githubusercontent.com/ShiWarai/WolfpackCloud-monitoring/main/agent/install.sh | sudo bash -s -- --server https://monitoring.example.com --name "Робот доставки #1"
```

## Что делает скрипт установки

1. **Определяет систему** — архитектуру и дистрибутив
2. **Устанавливает Telegraf** — через пакетный менеджер (apt/dnf/pacman)
3. **Генерирует код привязки** — уникальный 8-значный код
4. **Регистрирует робота** — отправляет данные на сервер (`POST /api/pair`)
5. **Ожидает подтверждения** — опрашивает сервер каждые 5 секунд (`GET /api/pair/{code}/status`)
6. **Получает токен** — после подтверждения пользователем получает персональный токен
7. **Настраивает Telegraf** — создаёт конфигурацию с токеном для отправки метрик через API
8. **Запускает сервис** — включает и запускает Telegraf

## Код привязки

После установки на экране появится 8-значный код:

```
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║   Код привязки для my-robot:                                     ║
║                                                                  ║
║              ┌──────────────────┐                                ║
║              │    ABCD1234      │                                ║
║              └──────────────────┘                                ║
║                                                                  ║
║   Код действителен 15 минут.                                     ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

**Важно**: Код действителен только 15 минут!

## Подтверждение привязки

1. Откройте веб-приложение на сервере (URL см. в `.env`)
2. Войдите под администратором (учётные данные в `.env`)
3. Перейдите в раздел "Привязка"
4. Введите 8-значный код
5. Нажмите "Подтвердить"

После подтверждения:
- Робот появится в списке со статусом "Активен"
- Telegraf начнёт отправлять метрики
- Данные отобразятся на дашборде через 10-30 секунд

## Ручная установка

Если автоматическая установка не подходит:

### 1. Установка Telegraf

```bash
# Debian/Ubuntu/Raspberry Pi OS
curl -fsSL https://repos.influxdata.com/influxdata-archive_compat.key | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/influxdata.gpg
echo "deb [signed-by=/etc/apt/trusted.gpg.d/influxdata.gpg] https://repos.influxdata.com/debian stable main" | sudo tee /etc/apt/sources.list.d/influxdata.list
sudo apt update
sudo apt install telegraf
```

### 2. Конфигурация

Создайте `/etc/telegraf/telegraf.conf`:

```toml
[global_tags]
  robot = "my-robot"

[agent]
  interval = "10s"
  flush_interval = "10s"

# Отправка метрик через API (не напрямую в InfluxDB)
[[outputs.http]]
  url = "https://monitoring.example.com/api/metrics"
  method = "POST"
  data_format = "influx"
  timeout = "10s"
  
  [outputs.http.headers]
    Authorization = "Bearer YOUR_ROBOT_TOKEN"
    Content-Type = "text/plain; charset=utf-8"

[[inputs.cpu]]
  percpu = true
  totalcpu = true

[[inputs.mem]]

[[inputs.disk]]
  ignore_fs = ["tmpfs", "devtmpfs"]

[[inputs.net]]

[[inputs.system]]

[[inputs.temp]]
```

**Важно**: `YOUR_ROBOT_TOKEN` — персональный токен, который робот получает после подтверждения привязки.

### 3. Запуск

```bash
sudo systemctl enable telegraf
sudo systemctl start telegraf
```

## Проверка статуса

```bash
# Статус сервиса
sudo systemctl status telegraf

# Логи
sudo journalctl -u telegraf -f

# Тест конфигурации
sudo telegraf --config /etc/telegraf/telegraf.conf --test
```

## Пакетная установка (Ansible)

Для установки на множество роботов используйте Ansible:

```bash
cd agent/ansible
cp inventory.example.yml inventory.yml
# Настройте inventory.yml

ansible-playbook -i inventory.yml playbook.yml
```

Подробнее: [[Server-Setup#ansible]]

## Удаление агента

```bash
sudo /home/ubuntu/WolfpackCloud-monitoring/agent/uninstall.sh
```

Или вручную:

```bash
sudo systemctl stop telegraf
sudo systemctl disable telegraf
sudo apt remove telegraf
sudo rm -rf /etc/telegraf
```
