#!/bin/bash
#
# WolfpackCloud Monitoring — Эмуляция робота-клиента для тестирования
# 
# Этот скрипт создаёт виртуального робота (Telegraf в контейнере),
# который отправляет метрики на локальный сервер мониторинга.
#
# Предварительно нужно запустить сервер: make dev
#
# Использование:
#   ./scripts/local-install.sh [--docker | --native]
#
# Опции:
#   --docker   Запустить Telegraf в Docker контейнере (по умолчанию)
#   --native   Установить Telegraf нативно на хост
#

set -euo pipefail

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Директория проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Режим установки
INSTALL_MODE="docker"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Проверка что сервер запущен
check_server_running() {
    log_info "Проверка что сервер запущен..."
    
    if ! curl -sf http://localhost:8000/health > /dev/null 2>&1; then
        log_error "Сервер не запущен. Сначала выполните: make dev"
    fi
    
    log_success "Сервер доступен"
}

# Генерация кода привязки
generate_pair_code() {
    head -c 100 /dev/urandom | tr -dc 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789' | head -c 8
}

# Установка Telegraf в Docker
install_telegraf_docker() {
    log_info "Запуск Telegraf в Docker контейнере..."
    
    local pair_code
    pair_code=$(generate_pair_code)
    local robot_name="local-test-robot"
    
    # Регистрация робота
    log_info "Регистрация тестового робота..."
    local response
    response=$(curl -sf -X POST "http://localhost:8000/api/pair" \
        -H "Content-Type: application/json" \
        -d "{
            \"hostname\": \"$(hostname)\",
            \"name\": \"${robot_name}\",
            \"ip_address\": \"127.0.0.1\",
            \"architecture\": \"amd64\",
            \"pair_code\": \"${pair_code}\"
        }") || log_error "Не удалось зарегистрировать робота"
    
    log_success "Робот зарегистрирован"
    
    # Автоматическое подтверждение привязки для тестирования
    log_info "Автоподтверждение привязки..."
    response=$(curl -sf -X POST "http://localhost:8000/api/pair/${pair_code}/confirm" \
        -H "Content-Type: application/json") || log_error "Не удалось подтвердить привязку"
    
    # Получаем токен из ответа status
    local status_response
    status_response=$(curl -sf "http://localhost:8000/api/pair/${pair_code}/status") || log_error "Не удалось получить статус"
    
    local robot_token
    robot_token=$(echo "$status_response" | grep -oP '"robot_token":\s*"\K[^"]+' || echo "")
    
    if [ -z "$robot_token" ]; then
        log_error "Не удалось получить токен робота"
    fi
    
    log_success "Привязка подтверждена, токен получен"
    
    # Создаём конфигурацию Telegraf с HTTP output (через API)
    local telegraf_config="/tmp/telegraf-local.conf"
    cat > "$telegraf_config" << EOF
[global_tags]
  robot = "${robot_name}"
  hostname = "$(hostname)"
  arch = "amd64"

[agent]
  interval = "10s"
  round_interval = true
  metric_batch_size = 1000
  metric_buffer_limit = 10000
  flush_interval = "10s"

# Отправка метрик через API
[[outputs.http]]
  url = "http://api:8000/api/metrics"
  method = "POST"
  data_format = "influx"
  timeout = "10s"
  
  [outputs.http.headers]
    Authorization = "Bearer ${robot_token}"
    Content-Type = "text/plain; charset=utf-8"

[[inputs.cpu]]
  percpu = true
  totalcpu = true

[[inputs.mem]]

[[inputs.disk]]
  ignore_fs = ["tmpfs", "devtmpfs", "overlay"]

[[inputs.system]]

[[inputs.net]]

[[inputs.processes]]

[[inputs.internal]]
  collect_memstats = false
EOF

    # Удаляем старый контейнер если есть
    docker rm -f wpc-telegraf-local 2>/dev/null || true
    
    # Определяем имя сети (зависит от имени директории проекта)
    local network_name
    network_name=$(docker network ls --format '{{.Name}}' | grep -E '_monitoring$' | head -1)
    if [ -z "$network_name" ]; then
        network_name="wolfpackcloud-monitoring_monitoring"
    fi
    
    # Запускаем Telegraf в контейнере
    docker run -d \
        --name wpc-telegraf-local \
        --network "$network_name" \
        -v "$telegraf_config:/etc/telegraf/telegraf.conf:ro" \
        telegraf:1.32-alpine
    
    log_success "Telegraf запущен в контейнере"
    
    # Сохраняем токен
    echo "$robot_token" > "$PROJECT_DIR/.local_robot_token"
    
    show_success_message "$pair_code"
}

# Установка Telegraf нативно
install_telegraf_native() {
    log_info "Нативная установка Telegraf..."
    
    # Используем скрипт установки агента
    bash "$PROJECT_DIR/agent/install.sh" --server "http://localhost:8000"
}

# Вывод информации об успешной установке
show_success_message() {
    local pair_code="$1"
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                  ║"
    echo "║   Виртуальный робот создан!                                      ║"
    echo "║                                                                  ║"
    echo "╠══════════════════════════════════════════════════════════════════╣"
    echo "║                                                                  ║"
    echo "║   Робот: local-test-robot                                        ║"
    echo "║   Код привязки: ${pair_code}                                     "
    echo "║                                                                  ║"
    echo "║   Метрики отправляются через API (POST /api/metrics).            ║"
    echo "║                                                                  ║"
    echo "║   Команды:                                                       ║"
    echo "║     Логи:     docker logs -f wpc-telegraf-local                  ║"
    echo "║     Стоп:     docker stop wpc-telegraf-local                     ║"
    echo "║     Удалить:  docker rm -f wpc-telegraf-local                    ║"
    echo "║                                                                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
}

# Обработка аргументов
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --docker)
                INSTALL_MODE="docker"
                shift
                ;;
            --native)
                INSTALL_MODE="native"
                shift
                ;;
            --help|-h)
                echo "Использование: $0 [--docker | --native]"
                echo ""
                echo "Опции:"
                echo "  --docker   Запустить Telegraf в Docker контейнере (по умолчанию)"
                echo "  --native   Установить Telegraf нативно на хост"
                exit 0
                ;;
            *)
                log_error "Неизвестная опция: $1"
                ;;
        esac
    done
}

# Главная функция
main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║   WolfpackCloud Monitoring — Эмуляция робота-клиента             ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    
    parse_args "$@"
    check_server_running
    
    if [ "$INSTALL_MODE" = "docker" ]; then
        install_telegraf_docker
    else
        install_telegraf_native
    fi
}

main "$@"
