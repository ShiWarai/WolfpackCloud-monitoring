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
TELEGRAF_CONF_DIR="/etc/telegraf"
TELEGRAF_CONF_FILE="${TELEGRAF_CONF_DIR}/telegraf.conf"

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
    # Генерируем 8-значный буквенно-цифровой код (без похожих символов: 0,O,1,l,I)
    tr -dc 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789' < /dev/urandom | head -c 8
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
    
    # Извлекаем токен InfluxDB из ответа
    local influx_token
    influx_token=$(echo "$response" | grep -oP '"influxdb_token":\s*"\K[^"]+' || echo "")
    
    if [ -z "$influx_token" ]; then
        log_warn "Токен InfluxDB не получен. Робот будет ожидать подтверждения."
        echo ""
    else
        echo "$influx_token"
    fi
}

# Настройка Telegraf
configure_telegraf() {
    local influx_token="$1"
    local robot_name="$2"
    
    log_info "Настройка Telegraf..."
    
    # Бэкап существующей конфигурации
    if [ -f "$TELEGRAF_CONF_FILE" ]; then
        cp "$TELEGRAF_CONF_FILE" "${TELEGRAF_CONF_FILE}.backup.$(date +%Y%m%d%H%M%S)"
    fi
    
    # Определяем URL для InfluxDB
    local influx_url="${SERVER_URL}/influxdb"
    # Если SERVER_URL заканчивается на порт, используем стандартный путь
    if [[ "$SERVER_URL" =~ :[0-9]+$ ]]; then
        influx_url="${SERVER_URL%:*}:8086"
    fi
    
    # Создаём конфигурацию из шаблона
    cat > "$TELEGRAF_CONF_FILE" << EOF
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

[[outputs.influxdb_v2]]
  urls = ["${influx_url}"]
  token = "${influx_token}"
  organization = "wolfpackcloud"
  bucket = "robots"
  timeout = "5s"

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
  grok_patterns = ["%{SYSLOGTIMESTAMP:timestamp} %{SYSLOGHOST:hostname} %{PROG:program}(?:\\[%{POSINT:pid}\\])?: %{GREEDYDATA:message}"]
  name_override = "syslog"
  [inputs.tail.tags]
    source = "file"

EOF

    # Настройка rsyslog для отправки логов в Telegraf
    if [ -d /etc/rsyslog.d ]; then
        cat > /etc/rsyslog.d/50-telegraf.conf << 'RSYSLOG'
# Отправка логов в Telegraf
*.* @127.0.0.1:6514
RSYSLOG
        systemctl restart rsyslog 2>/dev/null || true
    fi
    
    log_success "Telegraf настроен"
}

# Запуск Telegraf
start_telegraf() {
    log_info "Запуск Telegraf..."
    
    systemctl daemon-reload
    systemctl enable telegraf
    systemctl restart telegraf
    
    # Проверка статуса
    sleep 2
    if systemctl is-active --quiet telegraf; then
        log_success "Telegraf запущен и работает"
    else
        log_error "Не удалось запустить Telegraf. Проверьте: journalctl -u telegraf"
    fi
}

# Показать информацию о привязке
show_pairing_info() {
    local pair_code="$1"
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                  ║"
    echo "║   WolfpackCloud Monitoring Agent установлен успешно!             ║"
    echo "║                                                                  ║"
    echo "║   Для привязки робота к панели мониторинга:                      ║"
    echo "║                                                                  ║"
    echo "║   1. Откройте панель Grafana: ${SERVER_URL}                      "
    echo "║   2. Перейдите в Dashboard → 'Роботы'                            ║"
    echo "║   3. Нажмите 'Добавить робота'                                   ║"
    echo "║   4. Введите код привязки:                                       ║"
    echo "║                                                                  ║"
    echo "║              ┌──────────────────┐                                ║"
    echo "║              │    ${pair_code}        │                                ║"
    echo "║              └──────────────────┘                                ║"
    echo "║                                                                  ║"
    echo "║   Код действителен 15 минут.                                     ║"
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
            --help|-h)
                echo "Использование: $0 --server SERVER_URL [--name ROBOT_NAME]"
                echo ""
                echo "Опции:"
                echo "  --server, -s URL    URL сервера мониторинга (обязательно)"
                echo "  --name, -n NAME     Имя робота (по умолчанию: hostname)"
                echo "  --help, -h          Показать эту справку"
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

# Главная функция
main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║        WolfpackCloud Monitoring Agent - Установка                ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    
    parse_args "$@"
    check_root
    
    log_info "Архитектура: $(detect_arch)"
    log_info "Дистрибутив: $(detect_distro)"
    log_info "Hostname: $(get_hostname)"
    log_info "IP-адрес: $(get_ip_address)"
    log_info "Сервер: $SERVER_URL"
    echo ""
    
    # Генерируем код привязки
    local pair_code
    pair_code=$(generate_pair_code)
    
    # Установка Telegraf
    install_telegraf
    
    # Регистрация на сервере
    local influx_token
    influx_token=$(register_robot "$pair_code")
    
    # Если токен не получен, используем временный (будет обновлён после подтверждения)
    if [ -z "$influx_token" ]; then
        influx_token="pending_${pair_code}"
    fi
    
    # Настройка Telegraf
    local robot_name="${ROBOT_NAME:-$(get_hostname)}"
    configure_telegraf "$influx_token" "$robot_name"
    
    # Запуск Telegraf
    start_telegraf
    
    # Показываем информацию о привязке
    show_pairing_info "$pair_code"
    
    # Сохраняем код привязки для возможного повторного использования
    echo "$pair_code" > /etc/telegraf/.pair_code
    chmod 600 /etc/telegraf/.pair_code
}

main "$@"
