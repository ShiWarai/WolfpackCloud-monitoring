#!/bin/bash
#
# WolfpackCloud Monitoring — Локальная установка для тестирования
# 
# Этот скрипт:
# 1. Запускает серверный стек (Docker Compose)
# 2. Устанавливает Telegraf локально или в контейнере
# 3. Регистрирует "локального робота" для тестирования
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

# Проверка зависимостей
check_dependencies() {
    log_info "Проверка зависимостей..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker не установлен. Установите Docker: https://docs.docker.com/get-docker/"
    fi
    
    if ! command -v docker compose &> /dev/null && ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose не установлен"
    fi
    
    log_success "Все зависимости установлены"
}

# Создание .env файла если не существует
ensure_env_file() {
    if [ ! -f "$PROJECT_DIR/.env" ]; then
        log_info "Создание .env файла из шаблона..."
        
        if [ -f "$PROJECT_DIR/.env.example" ]; then
            cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
            
            # Генерируем случайные пароли для тестирования
            sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=testpassword123/" "$PROJECT_DIR/.env"
            sed -i "s/INFLUXDB_ADMIN_PASSWORD=.*/INFLUXDB_ADMIN_PASSWORD=testpassword123/" "$PROJECT_DIR/.env"
            sed -i "s/INFLUXDB_ADMIN_TOKEN=.*/INFLUXDB_ADMIN_TOKEN=test-token-for-development-only/" "$PROJECT_DIR/.env"
            sed -i "s/SECRET_KEY=.*/SECRET_KEY=test-secret-key-change-in-production/" "$PROJECT_DIR/.env"
            sed -i "s/SUPERSET_SECRET_KEY=.*/SUPERSET_SECRET_KEY=superset-test-secret-key/" "$PROJECT_DIR/.env"
            
            log_success ".env файл создан с тестовыми значениями"
        else
            log_error ".env.example не найден"
        fi
    else
        log_info ".env файл уже существует"
    fi
}

# Запуск серверного стека
start_server_stack() {
    log_info "Запуск серверного стека Docker Compose..."
    
    cd "$PROJECT_DIR"
    
    # Используем dev-конфигурацию для прямого доступа к портам
    docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build
    
    log_info "Ожидание готовности сервисов..."
    
    # Ожидаем готовности API
    local retries=30
    while [ $retries -gt 0 ]; do
        if curl -sf http://localhost:8000/health > /dev/null 2>&1; then
            break
        fi
        retries=$((retries - 1))
        echo -n "."
        sleep 2
    done
    echo ""
    
    if [ $retries -eq 0 ]; then
        log_error "Сервисы не запустились. Проверьте логи: docker compose logs"
    fi
    
    log_success "Серверный стек запущен"
}

# Генерация кода привязки
generate_pair_code() {
    tr -dc 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789' < /dev/urandom | head -c 8
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
    
    # Создаём временную конфигурацию Telegraf
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

[[outputs.influxdb_v2]]
  urls = ["http://influxdb:8086"]
  token = "test-token-for-development-only"
  organization = "wolfpackcloud"
  bucket = "robots"

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

    # Запускаем Telegraf в контейнере
    docker run -d \
        --name wpc-telegraf-local \
        --network wpc-monitoring_monitoring \
        -v "$telegraf_config:/etc/telegraf/telegraf.conf:ro" \
        telegraf:1.32-alpine
    
    log_success "Telegraf запущен в контейнере"
    
    # Сохраняем код привязки
    echo "$pair_code" > "$PROJECT_DIR/.local_pair_code"
    
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
    echo "║   WolfpackCloud Monitoring — Локальная установка завершена!      ║"
    echo "║                                                                  ║"
    echo "╠══════════════════════════════════════════════════════════════════╣"
    echo "║                                                                  ║"
    echo "║   Доступные сервисы:                                             ║"
    echo "║                                                                  ║"
    echo "║   • Grafana:    http://localhost:3000  (admin / admin)           ║"
    echo "║   • API:        http://localhost:8000/docs                       ║"
    echo "║   • Superset:   http://localhost:8088  (admin / admin)           ║"
    echo "║   • InfluxDB:   http://localhost:8086                            ║"
    echo "║   • PostgreSQL: localhost:5432                                   ║"
    echo "║                                                                  ║"
    echo "╠══════════════════════════════════════════════════════════════════╣"
    echo "║                                                                  ║"
    echo "║   Код привязки тестового робота:                                 ║"
    echo "║                                                                  ║"
    echo "║              ┌──────────────────┐                                ║"
    echo "║              │    ${pair_code}        │                                ║"
    echo "║              └──────────────────┘                                ║"
    echo "║                                                                  ║"
    echo "║   Для подтверждения привязки откройте Grafana и введите код.     ║"
    echo "║                                                                  ║"
    echo "╠══════════════════════════════════════════════════════════════════╣"
    echo "║                                                                  ║"
    echo "║   Для удаления: ./scripts/local-uninstall.sh                     ║"
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
    echo "║   WolfpackCloud Monitoring — Локальная установка для тестов      ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    
    parse_args "$@"
    check_dependencies
    ensure_env_file
    start_server_stack
    
    if [ "$INSTALL_MODE" = "docker" ]; then
        install_telegraf_docker
    else
        install_telegraf_native
    fi
}

main "$@"
