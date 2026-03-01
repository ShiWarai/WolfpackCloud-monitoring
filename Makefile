# =============================================================================
# WolfpackCloud Monitoring — Makefile
# =============================================================================

.PHONY: help install dev up down logs build test lint clean clean-data clean-docker agent agent-stop agent-logs

# Переменные
COMPOSE_FILE := docker-compose.yml
COMPOSE_DEV_FILE := docker-compose.dev.yml
API_DIR := server/api

# Цвета
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

help: ## Показать справку
	@echo ""
	@echo "$(BLUE)WolfpackCloud Monitoring$(NC)"
	@echo ""
	@echo "$(GREEN)Команды:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""

# =============================================================================
# Разработка
# =============================================================================

install: ## Установка зависимостей
	@echo "$(BLUE)Установка зависимостей Python...$(NC)"
	pip install -r $(API_DIR)/requirements.txt
	@echo "$(GREEN)Готово$(NC)"

install-dev: ## Установка зависимостей для разработки
	@echo "$(BLUE)Установка зависимостей Python (dev)...$(NC)"
	pip install -r $(API_DIR)/requirements.txt -r $(API_DIR)/requirements-dev.txt
	@echo "$(GREEN)Готово$(NC)"

dev: ## Запуск dev-окружения
	@echo "$(BLUE)Запуск dev-окружения...$(NC)"
	docker-compose -f $(COMPOSE_FILE) -f $(COMPOSE_DEV_FILE) up -d --build
	@echo "$(GREEN)Сервисы запущены:$(NC)"
	@echo "  API:      http://localhost:8000/docs"
	@echo "  Grafana:  http://localhost:3000"
	@echo "  Superset: http://localhost:8088 (или :9300)"
	@echo "  Client:   http://localhost:9101"

up: ## Запуск production стека
	@echo "$(BLUE)Запуск production стека...$(NC)"
	docker-compose -f $(COMPOSE_FILE) up -d
	@echo "$(GREEN)Готово$(NC)"

down: ## Остановка стека
	@echo "$(BLUE)Остановка стека...$(NC)"
	docker-compose -f $(COMPOSE_FILE) -f $(COMPOSE_DEV_FILE) down
	@echo "$(GREEN)Готово$(NC)"

logs: ## Показать логи
	docker-compose -f $(COMPOSE_FILE) -f $(COMPOSE_DEV_FILE) logs -f

restart: ## Перезапуск стека
	@echo "$(BLUE)Перезапуск стека...$(NC)"
	docker-compose -f $(COMPOSE_FILE) -f $(COMPOSE_DEV_FILE) restart
	@echo "$(GREEN)Готово$(NC)"

# =============================================================================
# Сборка
# =============================================================================

build: ## Сборка Docker образов
	@echo "$(BLUE)Сборка образов...$(NC)"
	docker-compose -f $(COMPOSE_FILE) build
	@echo "$(GREEN)Готово$(NC)"

build-api: ## Сборка только API образа
	@echo "$(BLUE)Сборка API образа...$(NC)"
	docker build -t wpc-monitoring-api $(API_DIR)
	@echo "$(GREEN)Готово$(NC)"

build-client: ## Сборка только Client образа
	@echo "$(BLUE)Сборка Client образа...$(NC)"
	docker build -t wpc-monitoring-client client
	@echo "$(GREEN)Готово$(NC)"

# =============================================================================
# Тестирование
# =============================================================================

test: ## Запуск тестов
	@echo "$(BLUE)Запуск тестов...$(NC)"
	cd $(API_DIR) && pytest tests/ -v
	@echo "$(GREEN)Готово$(NC)"

test-cov: ## Запуск тестов с покрытием
	@echo "$(BLUE)Запуск тестов с покрытием...$(NC)"
	cd $(API_DIR) && pytest tests/ -v --cov=app --cov-report=html
	@echo "$(GREEN)Отчёт: $(API_DIR)/htmlcov/index.html$(NC)"

# =============================================================================
# Линтинг
# =============================================================================

lint: ## Линтинг кода
	@echo "$(BLUE)Линтинг Python...$(NC)"
	ruff check $(API_DIR)
	ruff format --check $(API_DIR)
	@echo "$(GREEN)Готово$(NC)"

lint-fix: ## Автоисправление линтинга
	@echo "$(BLUE)Исправление линтинга...$(NC)"
	ruff check --fix $(API_DIR)
	ruff format $(API_DIR)
	@echo "$(GREEN)Готово$(NC)"

# =============================================================================
# Тестовый агент (для локальной разработки)
# Использование: make agent NAME=robot-01
# =============================================================================

NAME ?= test-agent

agent: ## Запуск тестового агента (NAME=имя для уникальных агентов)
	@echo "$(BLUE)Запуск агента '$(NAME)' (install.sh --docker)...$(NC)"
	@mkdir -p .agent-data/$(NAME)
	@network=$$(docker network ls --format '{{.Name}}' | grep -E 'monitoring$$' | head -1); \
	SERVER_URL=http://localhost:8000 \
	ROBOT_NAME=$(NAME) \
	AGENT_DATA_DIR=$(PWD)/.agent-data/$(NAME) \
	DOCKER_NETWORK=$$network \
	bash $(PWD)/agent/install.sh --docker --server http://localhost:8000 --name $(NAME) --metrics-url http://api:8000/api/metrics

agent-stop: ## Остановка агента (NAME=имя или все если не указано)
	@if [ "$(NAME)" = "test-agent" ]; then \
		echo "$(BLUE)Остановка всех агентов wpc-telegraf-*...$(NC)"; \
		docker ps -a --format '{{.Names}}' | grep '^wpc-telegraf-' | xargs -r docker rm -f 2>/dev/null || true; \
	else \
		echo "$(BLUE)Остановка агента wpc-telegraf-$(NAME)...$(NC)"; \
		docker rm -f wpc-telegraf-$(NAME) 2>/dev/null || true; \
	fi
	@echo "$(GREEN)Готово$(NC)"

agent-logs: ## Логи агента (NAME=имя)
	docker logs -f wpc-telegraf-$(NAME)

# =============================================================================
# База данных
# =============================================================================

db-shell: ## Подключение к PostgreSQL
	docker-compose exec postgres psql -U monitoring -d monitoring

db-migrate: ## Применение миграций (если есть)
	docker-compose exec api alembic upgrade head

influx-shell: ## Подключение к InfluxDB CLI
	docker-compose exec influxdb influx

# =============================================================================
# Очистка
# =============================================================================

clean: ## Очистка временных файлов
	@echo "$(BLUE)Очистка...$(NC)"
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".ruff_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name "htmlcov" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true
	find . -type f -name ".coverage" -delete 2>/dev/null || true
	rm -f .local_pair_code .local_robot_token 2>/dev/null || true
	rm -rf .agent-data 2>/dev/null || true
	@echo "$(GREEN)Готово$(NC)"

clean-data: ## Очистка всех данных в БД (метрики и роботы)
	@echo "$(YELLOW)Очистка данных в InfluxDB и PostgreSQL...$(NC)"
	@docker-compose exec -T influxdb influx delete \
		--bucket robots \
		--org wolfpackcloud \
		--start '1970-01-01T00:00:00Z' \
		--stop '2030-01-01T00:00:00Z' 2>/dev/null || true
	@docker-compose exec -T postgres psql -U monitoring -d monitoring -c "TRUNCATE pair_codes, robots RESTART IDENTITY CASCADE;" 2>/dev/null || true
	@docker rm -f wpc-telegraf-local $(AGENT_TELEGRAF) 2>/dev/null || true
	@rm -f .local_robot_token 2>/dev/null || true
	@rm -rf .agent-data 2>/dev/null || true
	@echo "$(GREEN)Данные очищены$(NC)"

clean-docker: ## Очистка Docker ресурсов (удалит все данные!)
	@echo "$(YELLOW)Внимание: это удалит все данные!$(NC)"
	@read -p "Продолжить? (y/N): " confirm && [ "$$confirm" = "y" ]
	docker-compose -f $(COMPOSE_FILE) -f $(COMPOSE_DEV_FILE) down -v --rmi local
	docker image prune -f
	@echo "$(GREEN)Готово$(NC)"

# =============================================================================
# Утилиты
# =============================================================================

env: ## Создание .env из шаблона
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "$(GREEN).env создан из .env.example$(NC)"; \
		echo "$(YELLOW)Не забудьте настроить переменные!$(NC)"; \
	else \
		echo "$(YELLOW).env уже существует$(NC)"; \
	fi

ps: ## Статус контейнеров
	docker-compose -f $(COMPOSE_FILE) -f $(COMPOSE_DEV_FILE) ps

health: ## Проверка health всех сервисов
	@echo "$(BLUE)Проверка сервисов...$(NC)"
	@curl -sf http://localhost:8000/health && echo "$(GREEN)API: OK$(NC)" || echo "$(YELLOW)API: недоступен$(NC)"
	@curl -sf http://localhost:3000/api/health && echo "$(GREEN)Grafana: OK$(NC)" || echo "$(YELLOW)Grafana: недоступен$(NC)"
	@curl -sf http://localhost:8086/health && echo "$(GREEN)InfluxDB: OK$(NC)" || echo "$(YELLOW)InfluxDB: недоступен$(NC)"
