#!/bin/bash
#
# WolfpackCloud Monitoring Agent - Скрипт установки
# Устанавливает Telegraf на одноплатный компьютер робота и регистрирует его в панели мониторинга
#
# Использование:
#   curl -fsSL https://raw.githubusercontent.com/ShiWarai/WolfpackCloud-monitoring/main/agent/install.sh | bash -s -- --server https://monitoring.example.com
#   или
#   ./install.sh --server https://monitoring.example.com [--name ROBOT_NAME]
#

set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Конфигурация по умолчанию
SERVER_URL=""
ROBOT_NAME=""
DOCKER_MODE=false
METRICS_URL=""  # Явный URL для отправки метрик (если отличается от SERVER_URL)
TELEGRAF_CONF_DIR="/etc/telegraf"
TELEGRAF_CONF_FILE="${TELEGRAF_CONF_DIR}/telegraf.conf"
TELEGRAF_CONTAINER_NAME="wpc-monitoring-agent"

# Логирование
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Проверка root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Этот скрипт должен быть запущен с правами root (sudo)"
    fi
}

# Определение архитектуры
detect_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7l|armhf)
            echo "armhf"
            ;;
        *)
            log_error "Неподдерживаемая архитектура: $arch"
            ;;
    esac
}

# Определение дистрибутива
detect_distro() {
    if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    else
        log_error "Не удалось определить дистрибутив"
    fi
}

# Генерация 8-значного кода привязки
generate_pair_code() {
    local chars="ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    local code=""
    local i
    for i in $(seq 1 8); do
        code="${code}${chars:$((RANDOM % ${#chars})):1}"
    done
    echo "$code"
}

# Получение hostname
get_hostname() {
    hostname -f 2>/dev/null || hostname
}

# Получение IP-адреса
get_ip_address() {
    # Приоритет: первый не-loopback IPv4 адрес
    ip -4 route get 1 2>/dev/null | awk '{print $7; exit}' || \
    hostname -I 2>/dev/null | awk '{print $1}' || \
    echo "unknown"
}

# Установка Telegraf
install_telegraf() {
    local distro
    distro=$(detect_distro)
    
    log_info "Установка Telegraf для $distro..."
    
    case "$distro" in
        ubuntu|debian|raspbian)
            # Добавляем репозиторий InfluxData
            if [ ! -f /etc/apt/sources.list.d/influxdata.list ]; then
                log_info "Добавление репозитория InfluxData..."
                curl -fsSL https://repos.influxdata.com/influxdata-archive_compat.key | gpg --dearmor -o /etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg
                echo "deb [signed-by=/etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg] https://repos.influxdata.com/debian stable main" > /etc/apt/sources.list.d/influxdata.list
            fi
            apt-get update -qq
            apt-get install -y telegraf
            ;;
        fedora|centos|rhel|rocky|almalinux)
            # Добавляем репозиторий InfluxData
            cat <<EOF > /etc/yum.repos.d/influxdata.repo
[influxdata]
name = InfluxData Repository
baseurl = https://repos.influxdata.com/rhel/\$releasever/\$basearch/stable
enabled = 1
gpgcheck = 1
gpgkey = https://repos.influxdata.com/influxdata-archive_compat.key
EOF
            dnf install -y telegraf || yum install -y telegraf
            ;;
        arch|manjaro)
            pacman -Sy --noconfirm telegraf
            ;;
        *)
            log_error "Дистрибутив $distro не поддерживается. Установите Telegraf вручную."
            ;;
    esac
    
    log_success "Telegraf установлен"
}

# Установка Telegraf в Docker-режиме (проверка Docker, pull образа)
install_telegraf_docker() {
    log_info "Режим Docker: проверка наличия Docker..."

    if ! command -v docker &>/dev/null; then
        log_error "Docker не найден. Установите Docker: https://docs.docker.com/engine/install/"
    fi

    if ! docker info &>/dev/null; then
        log_error "Docker daemon недоступен. Убедитесь, что Docker запущен и у вас есть права."
    fi

    log_info "Загрузка образа Telegraf..."
    docker pull telegraf:1.32-alpine
    log_success "Telegraf (Docker) готов"
}

# Регистрация робота на сервере
register_robot() {
    local pair_code="$1"
    local hostname
    local ip_address
    local arch
    
    hostname=$(get_hostname)
    ip_address=$(get_ip_address)
    arch=$(detect_arch)
    
    log_info "Регистрация робота на сервере..."
    
    local response
    response=$(curl -fsSL -X POST "${SERVER_URL}/api/pair" \
        -H "Content-Type: application/json" \
        -d "{
            \"hostname\": \"${hostname}\",
            \"name\": \"${ROBOT_NAME:-$hostname}\",
            \"ip_address\": \"${ip_address}\",
            \"architecture\": \"${arch}\",
            \"pair_code\": \"${pair_code}\"
        }" 2>&1) || log_error "Не удалось связаться с сервером: $response"
    
    log_success "Робот зарегистрирован. Ожидание подтверждения..."
}

# Ожидание подтверждения привязки (polling)
wait_for_confirmation() {
    local pair_code="$1"
    local timeout_seconds=900  # 15 минут
    local poll_interval=5
    local elapsed=0
    
    log_info "Ожидание подтверждения привязки..."
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                  ║"
    echo "║   Для привязки робота введите код в панели управления:           ║"
    echo "║                                                                  ║"
    echo "║              ┌──────────────────┐                                ║"
    echo "║              │    ${pair_code}        │                                ║"
    echo "║              └──────────────────┘                                ║"
    echo "║                                                                  ║"
    echo "║   Панель управления: ${SERVER_URL}                               "
    echo "║   Код действителен 15 минут.                                     ║"
    echo "║                                                                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    
    while [ $elapsed -lt $timeout_seconds ]; do
        local response
        response=$(curl -sfL "${SERVER_URL}/api/pair/${pair_code}/status" 2>/dev/null || echo "")
        
        if [ -z "$response" ]; then
            log_warn "Не удалось связаться с сервером. Повторная попытка..."
            sleep $poll_interval
            elapsed=$((elapsed + poll_interval))
            continue
        fi
        
        local status
        status=$(echo "$response" | grep -oP '"status":\s*"\K[^"]+' || echo "pending")
        
        case "$status" in
            confirmed)
                local robot_token
                local api_url
                robot_token=$(echo "$response" | grep -oP '"robot_token":\s*"\K[^"]+' || echo "")
                api_url=$(echo "$response" | grep -oP '"api_url":\s*"\K[^"]+' || echo "${SERVER_URL}/api/metrics")
                
                if [ -n "$robot_token" ]; then
                    log_success "Привязка подтверждена!"
                    # Возвращаем токен и URL через глобальные переменные
                    ROBOT_TOKEN="$robot_token"
                    API_URL="$api_url"
                    return 0
                else
                    log_error "Токен не получен после подтверждения"
                fi
                ;;
            expired)
                log_error "Срок действия кода привязки истёк. Запустите установку заново."
                ;;
            pending)
                echo -n "."
                ;;
        esac
        
        sleep $poll_interval
        elapsed=$((elapsed + poll_interval))
    done
    
    echo ""
    log_error "Время ожидания подтверждения истекло. Запустите установку заново."
}

# Настройка Telegraf
configure_telegraf() {
    local robot_token="$1"
    local api_url="$2"
    local robot_name="$3"
    local conf_file="$TELEGRAF_CONF_FILE"

    # Используем явно указанный METRICS_URL, если задан
    if [ -n "$METRICS_URL" ]; then
        api_url="$METRICS_URL"
    fi

    if [ "$DOCKER_MODE" = true ]; then
        conf_file="${AGENT_DATA_DIR:-/tmp}/telegraf.conf"
        mkdir -p "$(dirname "$conf_file")"
    fi

    log_info "Настройка Telegraf..."

    # Бэкап существующей конфигурации (только для нативного режима)
    if [ "$DOCKER_MODE" = false ] && [ -f "$conf_file" ]; then
        cp "$conf_file" "${conf_file}.backup.$(date +%Y%m%d%H%M%S)"
    fi

    # Создаём конфигурацию
    cat > "$conf_file" << EOF
# Конфигурация Telegraf для WolfpackCloud Monitoring
# Сгенерировано автоматически: $(date -Iseconds)
# Робот: ${robot_name}

[global_tags]
  robot = "${robot_name}"
  hostname = "$(get_hostname)"
  arch = "$(detect_arch)"

[agent]
  interval = "10s"
  round_interval = true
  metric_batch_size = 1000
  metric_buffer_limit = 10000
  collection_jitter = "0s"
  flush_interval = "10s"
  flush_jitter = "0s"
  precision = "0s"
  hostname = ""
  omit_hostname = false

###############################################################################
#                            OUTPUT PLUGINS                                   #
###############################################################################

# Отправка метрик через API (проксируется в InfluxDB)
[[outputs.http]]
  url = "${api_url}"
  method = "POST"
  data_format = "influx"
  timeout = "10s"
  content_encoding = "gzip"
  
  [outputs.http.headers]
    Authorization = "Bearer ${robot_token}"
    Content-Type = "text/plain; charset=utf-8"

###############################################################################
#                            INPUT PLUGINS                                    #
###############################################################################

# CPU
[[inputs.cpu]]
  percpu = true
  totalcpu = true
  collect_cpu_time = false
  report_active = false

# Память
[[inputs.mem]]

# Swap
[[inputs.swap]]

# Диск
[[inputs.disk]]
  ignore_fs = ["tmpfs", "devtmpfs", "devfs", "iso9660", "overlay", "aufs", "squashfs"]

# Disk I/O
[[inputs.diskio]]

# Сеть
[[inputs.net]]
  ignore_protocol_stats = true

# Система
[[inputs.system]]

# Процессы
[[inputs.processes]]

# Температура CPU (важно для ARM SBC)
[[inputs.temp]]

# Uptime
[[inputs.kernel]]

# Системные логи
[[inputs.syslog]]
  server = "udp://127.0.0.1:6514"

# Логи из файлов
[[inputs.tail]]
  files = ["/var/log/syslog", "/var/log/messages"]
  from_beginning = false
  data_format = "grok"
  grok_patterns = ['%{SYSLOGTIMESTAMP:timestamp} %{SYSLOGHOST:hostname} %{PROG:program}(?:\[%{POSINT:pid}\])?: %{GREEDYDATA:message}']
  name_override = "syslog"
  [inputs.tail.tags]
    source = "file"

EOF

    # Настройка rsyslog для отправки логов в Telegraf (только нативный режим)
    if [ "$DOCKER_MODE" = false ] && [ -d /etc/rsyslog.d ]; then
        cat > /etc/rsyslog.d/50-telegraf.conf << 'RSYSLOG'
# Отправка логов в Telegraf
*.* @127.0.0.1:6514
RSYSLOG
        systemctl restart rsyslog 2>/dev/null || true
    fi

    # Сохраняем путь к конфигу для Docker-режима
    TELEGRAF_CONF_FILE="$conf_file"
    
    log_success "Telegraf настроен"
}

# Запуск Telegraf
start_telegraf() {
    log_info "Запуск Telegraf..."

    if [ "$DOCKER_MODE" = true ]; then
        # Остановить и удалить старый контейнер, если есть
        docker rm -f "$TELEGRAF_CONTAINER_NAME" 2>/dev/null || true

        # Путь к конфигу для volume: хост-путь если задан (для make agent), иначе локальный
        local conf_volume_path="${TELEGRAF_CONF_HOST_PATH:-$TELEGRAF_CONF_FILE}"

        local docker_args=(
            run -d
            --name "$TELEGRAF_CONTAINER_NAME"
            --restart unless-stopped
            -v "${conf_volume_path}:/etc/telegraf/telegraf.conf:ro"
        )

        # Подключить к сети мониторинга, если указана
        if [ -n "${DOCKER_NETWORK:-}" ]; then
            docker_args+=(--network "$DOCKER_NETWORK")
        fi

        docker_args+=(telegraf:1.32-alpine)

        docker "${docker_args[@]}" || log_error "Не удалось запустить контейнер Telegraf"

        sleep 2
        if docker ps --format '{{.Names}}' | grep -q "^${TELEGRAF_CONTAINER_NAME}$"; then
            log_success "Telegraf (Docker) запущен и работает"
        else
            log_error "Не удалось запустить Telegraf. Проверьте: docker logs $TELEGRAF_CONTAINER_NAME"
        fi
    else
        systemctl daemon-reload
        systemctl enable telegraf
        systemctl restart telegraf

        sleep 2
        if systemctl is-active --quiet telegraf; then
            log_success "Telegraf запущен и работает"
        else
            log_error "Не удалось запустить Telegraf. Проверьте: journalctl -u telegraf"
        fi
    fi
}

# Показать информацию об успешной установке
show_success_info() {
    local robot_name="$1"
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                  ║"
    echo "║   WolfpackCloud Monitoring Agent установлен успешно!             ║"
    echo "║                                                                  ║"
    echo "║   Робот: ${robot_name}                                           "
    echo "║   Сервер: ${SERVER_URL}                                          "
    echo "║                                                                  ║"
    if [ "$DOCKER_MODE" = true ]; then
        echo "║   Метрики отправляются через API (Docker).                        ║"
        echo "║   Проверить: docker ps | grep $TELEGRAF_CONTAINER_NAME              "
        echo "║   Логи: docker logs -f $TELEGRAF_CONTAINER_NAME                      "
    else
        echo "║   Метрики отправляются через API.                                ║"
        echo "║   Проверить статус: systemctl status telegraf                    ║"
        echo "║   Логи: journalctl -u telegraf -f                                ║"
    fi
    echo "║                                                                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
}

# Обработка аргументов
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --server|-s)
                SERVER_URL="$2"
                shift 2
                ;;
            --name|-n)
                ROBOT_NAME="$2"
                shift 2
                ;;
            --docker)
                DOCKER_MODE=true
                shift
                ;;
            --metrics-url|-m)
                METRICS_URL="$2"
                shift 2
                ;;
            --help|-h)
                echo "Использование: $0 --server SERVER_URL [--name ROBOT_NAME] [--docker] [--metrics-url URL]"
                echo ""
                echo "Опции:"
                echo "  --server, -s URL       URL сервера мониторинга (обязательно)"
                echo "  --name, -n NAME        Имя робота (по умолчанию: hostname)"
                echo "  --docker               Запуск Telegraf в Docker вместо нативной установки"
                echo "  --metrics-url, -m URL  URL для отправки метрик (по умолчанию: SERVER_URL/api/metrics)"
                echo "  --help, -h             Показать эту справку"
                echo ""
                echo "Примеры:"
                echo "  $0 --server https://monitoring.example.com"
                echo "  $0 --server https://monitoring.example.com --name my-robot"
                echo "  $0 --server https://monitoring.example.com --docker"
                exit 0
                ;;
            *)
                log_error "Неизвестная опция: $1"
                ;;
        esac
    done
    
    if [ -z "$SERVER_URL" ]; then
        log_error "Необходимо указать URL сервера: --server https://monitoring.example.com"
    fi
    
    # Убираем trailing slash
    SERVER_URL="${SERVER_URL%/}"
}

# Глобальные переменные для токена (заполняются после подтверждения)
ROBOT_TOKEN=""
API_URL=""

# Главная функция
main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║        WolfpackCloud Monitoring Agent - Установка                ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    
    parse_args "$@"
    
    # Root нужен только для нативной установки
    if [ "$DOCKER_MODE" = false ]; then
        check_root
    fi
    
    log_info "Архитектура: $(detect_arch)"
    log_info "Дистрибутив: $(detect_distro)"
    log_info "Hostname: $(get_hostname)"
    log_info "IP-адрес: $(get_ip_address)"
    log_info "Сервер: $SERVER_URL"
    echo ""
    
    # Генерируем код привязки
    local pair_code
    pair_code=$(generate_pair_code)
    
    # Установка Telegraf (нативная или Docker)
    if [ "$DOCKER_MODE" = true ]; then
        install_telegraf_docker
    else
        install_telegraf
    fi
    
    # Регистрация на сервере
    register_robot "$pair_code"
    
    # Ожидание подтверждения (polling)
    wait_for_confirmation "$pair_code"
    
    # После подтверждения ROBOT_TOKEN и API_URL заполнены
    local robot_name="${ROBOT_NAME:-$(get_hostname)}"
    
    # Настройка Telegraf с полученным токеном
    configure_telegraf "$ROBOT_TOKEN" "$API_URL" "$robot_name"
    
    # Запуск Telegraf
    start_telegraf
    
    # Показываем информацию об успешной установке
    show_success_info "$robot_name"
    
    # Сохраняем токен для возможного повторного использования
    if [ "$DOCKER_MODE" = true ]; then
        local token_dir="${AGENT_DATA_DIR:-/tmp}"
        mkdir -p "$token_dir"
        echo "$ROBOT_TOKEN" > "${token_dir}/.robot_token"
        chmod 600 "${token_dir}/.robot_token"
    else
        echo "$ROBOT_TOKEN" > /etc/telegraf/.robot_token
        chmod 600 /etc/telegraf/.robot_token
    fi
}

main "$@"
