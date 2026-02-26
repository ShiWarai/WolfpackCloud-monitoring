#!/bin/bash
#
# WolfpackCloud Monitoring — Удаление локальной установки
#
# Использование:
#   ./scripts/local-uninstall.sh [--keep-data]
#
# Опции:
#   --keep-data   Сохранить данные (volumes Docker)
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

KEEP_DATA=false

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Остановка и удаление Telegraf контейнера
remove_telegraf_container() {
    log_info "Удаление контейнера Telegraf..."
    
    if docker ps -a --format '{{.Names}}' | grep -q "wpc-telegraf-local"; then
        docker stop wpc-telegraf-local 2>/dev/null || true
        docker rm wpc-telegraf-local 2>/dev/null || true
        log_success "Контейнер Telegraf удалён"
    else
        log_info "Контейнер Telegraf не найден"
    fi
    
    # Удаление временной конфигурации
    rm -f /tmp/telegraf-local.conf
}

# Остановка Docker Compose стека
stop_server_stack() {
    log_info "Остановка серверного стека..."
    
    cd "$PROJECT_DIR"
    
    if [ "$KEEP_DATA" = true ]; then
        docker compose -f docker-compose.yml -f docker-compose.dev.yml down
        log_info "Данные сохранены в Docker volumes"
    else
        docker compose -f docker-compose.yml -f docker-compose.dev.yml down -v
        log_success "Все контейнеры и данные удалены"
    fi
}

# Очистка временных файлов
cleanup_temp_files() {
    log_info "Очистка временных файлов..."
    
    rm -f "$PROJECT_DIR/.local_pair_code"
    
    log_success "Временные файлы удалены"
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
                echo "  --keep-data   Сохранить данные (volumes Docker)"
                exit 0
                ;;
            *)
                log_warn "Неизвестная опция: $1"
                shift
                ;;
        esac
    done
}

# Главная функция
main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║   WolfpackCloud Monitoring — Удаление локальной установки        ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    
    parse_args "$@"
    
    # Подтверждение
    if [ "$KEEP_DATA" = false ]; then
        echo -e "${YELLOW}Внимание!${NC} Все данные будут удалены."
        read -p "Продолжить? (y/N): " -n 1 -r
        echo ""
        
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Операция отменена"
            exit 0
        fi
    fi
    
    echo ""
    
    remove_telegraf_container
    stop_server_stack
    cleanup_temp_files
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                  ║"
    echo "║   Локальная установка удалена!                                   ║"
    echo "║                                                                  ║"
    if [ "$KEEP_DATA" = true ]; then
    echo "║   Данные сохранены в Docker volumes.                             ║"
    echo "║   Для полного удаления: docker volume prune                      ║"
    echo "║                                                                  ║"
    fi
    echo "║   Для повторной установки: ./scripts/local-install.sh            ║"
    echo "║                                                                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
}

main "$@"
