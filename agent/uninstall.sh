#!/bin/bash
#
# WolfpackCloud Monitoring Agent - Скрипт удаления
# Полностью удаляет агент мониторинга с устройства
#
# Использование:
#   sudo ./uninstall.sh [--keep-data]
#

set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

KEEP_DATA=false

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

# Определение дистрибутива
detect_distro() {
    if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

# Остановка Telegraf
stop_telegraf() {
    log_info "Остановка сервиса Telegraf..."
    
    if systemctl is-active --quiet telegraf 2>/dev/null; then
        systemctl stop telegraf
        systemctl disable telegraf
        log_success "Telegraf остановлен"
    else
        log_warn "Telegraf не был запущен"
    fi
}

# Удаление Telegraf
remove_telegraf() {
    local distro
    distro=$(detect_distro)
    
    log_info "Удаление Telegraf..."
    
    case "$distro" in
        ubuntu|debian|raspbian)
            apt-get remove -y telegraf || true
            apt-get autoremove -y || true
            ;;
        fedora|centos|rhel|rocky|almalinux)
            dnf remove -y telegraf || yum remove -y telegraf || true
            ;;
        arch|manjaro)
            pacman -Rs --noconfirm telegraf || true
            ;;
        *)
            log_warn "Дистрибутив $distro не распознан. Попытка удаления вручную..."
            rm -f /usr/bin/telegraf
            ;;
    esac
    
    log_success "Telegraf удалён"
}

# Удаление конфигурации
remove_config() {
    log_info "Удаление конфигурационных файлов..."
    
    # Удаление конфигурации Telegraf
    if [ -d /etc/telegraf ]; then
        if [ "$KEEP_DATA" = true ]; then
            log_info "Сохранение резервных копий конфигурации..."
            # Сохраняем только .backup файлы
            find /etc/telegraf -type f ! -name "*.backup*" -delete
        else
            rm -rf /etc/telegraf
        fi
        log_success "Конфигурация Telegraf удалена"
    fi
    
    # Удаление rsyslog конфигурации
    if [ -f /etc/rsyslog.d/50-telegraf.conf ]; then
        rm -f /etc/rsyslog.d/50-telegraf.conf
        systemctl restart rsyslog 2>/dev/null || true
        log_success "Конфигурация rsyslog удалена"
    fi
}

# Удаление репозитория InfluxData
remove_repo() {
    log_info "Удаление репозитория InfluxData..."
    
    # Debian/Ubuntu
    rm -f /etc/apt/sources.list.d/influxdata.list
    rm -f /etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg
    
    # RHEL/CentOS
    rm -f /etc/yum.repos.d/influxdata.repo
    
    log_success "Репозиторий InfluxData удалён"
}

# Удаление данных
remove_data() {
    if [ "$KEEP_DATA" = true ]; then
        log_info "Данные сохранены (--keep-data)"
        return
    fi
    
    log_info "Удаление данных..."
    
    # Удаление логов Telegraf
    rm -rf /var/log/telegraf
    
    # Удаление lib данных
    rm -rf /var/lib/telegraf
    
    log_success "Данные удалены"
}

# Обработка аргументов
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --keep-data)
                KEEP_DATA=true
                shift
                ;;
            --help|-h)
                echo "Использование: $0 [--keep-data]"
                echo ""
                echo "Опции:"
                echo "  --keep-data    Сохранить данные и резервные копии конфигурации"
                echo "  --help, -h     Показать эту справку"
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
    echo "║        WolfpackCloud Monitoring Agent - Удаление                 ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    
    parse_args "$@"
    check_root
    
    # Подтверждение
    echo -e "${YELLOW}Внимание!${NC} Это действие полностью удалит агент мониторинга."
    if [ "$KEEP_DATA" = false ]; then
        echo -e "${YELLOW}Все данные и конфигурация будут удалены.${NC}"
    else
        echo -e "${BLUE}Данные и резервные копии будут сохранены (--keep-data).${NC}"
    fi
    echo ""
    read -p "Продолжить? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Операция отменена"
        exit 0
    fi
    
    echo ""
    
    stop_telegraf
    remove_telegraf
    remove_config
    remove_repo
    remove_data
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                  ║"
    echo "║   WolfpackCloud Monitoring Agent успешно удалён!                 ║"
    echo "║                                                                  ║"
    if [ "$KEEP_DATA" = true ]; then
    echo "║   Резервные копии сохранены в /etc/telegraf                      ║"
    echo "║                                                                  ║"
    fi
    echo "║   Для повторной установки выполните:                             ║"
    echo "║   curl -fsSL https://raw.githubusercontent.com/ShiWarai/         ║"
    echo "║   WolfpackCloud-monitoring/main/agent/install.sh | bash          ║"
    echo "║                                                                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
}

main "$@"
