-- =============================================================================
-- WolfpackCloud Monitoring — Инициализация PostgreSQL
-- =============================================================================
-- Создаёт таблицы для реестра роботов, кодов привязки и пользователей
-- Выполняется автоматически при первом запуске контейнера
-- =============================================================================

-- Расширения
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================================================
-- ENUM типы
-- =============================================================================

CREATE TYPE robot_status AS ENUM ('pending', 'active', 'inactive', 'error');
CREATE TYPE architecture AS ENUM ('arm64', 'amd64', 'armhf');
CREATE TYPE pair_code_status AS ENUM ('pending', 'confirmed', 'expired');

-- =============================================================================
-- Таблица роботов
-- =============================================================================

CREATE TABLE IF NOT EXISTS robots (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    hostname VARCHAR(255) NOT NULL,
    ip_address VARCHAR(45),
    architecture architecture NOT NULL DEFAULT 'arm64',
    status robot_status NOT NULL DEFAULT 'pending',
    influxdb_token TEXT,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ
);

-- Индексы для частых запросов
CREATE INDEX IF NOT EXISTS idx_robots_status ON robots(status);
CREATE INDEX IF NOT EXISTS idx_robots_hostname ON robots(hostname);
CREATE INDEX IF NOT EXISTS idx_robots_last_seen ON robots(last_seen_at DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_robots_created ON robots(created_at DESC);

-- Комментарии
COMMENT ON TABLE robots IS 'Реестр зарегистрированных роботов в системе мониторинга';
COMMENT ON COLUMN robots.name IS 'Пользовательское имя робота';
COMMENT ON COLUMN robots.hostname IS 'Hostname устройства';
COMMENT ON COLUMN robots.ip_address IS 'IP-адрес робота (IPv4 или IPv6)';
COMMENT ON COLUMN robots.architecture IS 'Архитектура процессора (arm64, amd64, armhf)';
COMMENT ON COLUMN robots.status IS 'Текущий статус робота';
COMMENT ON COLUMN robots.influxdb_token IS 'Токен для записи метрик в InfluxDB';
COMMENT ON COLUMN robots.last_seen_at IS 'Время последней активности (heartbeat или метрики)';

-- =============================================================================
-- Таблица кодов привязки
-- =============================================================================

CREATE TABLE IF NOT EXISTS pair_codes (
    id SERIAL PRIMARY KEY,
    code VARCHAR(8) NOT NULL UNIQUE,
    robot_id INTEGER NOT NULL REFERENCES robots(id) ON DELETE CASCADE,
    status pair_code_status NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    confirmed_at TIMESTAMPTZ
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_pair_codes_code ON pair_codes(code);
CREATE INDEX IF NOT EXISTS idx_pair_codes_status ON pair_codes(status);
CREATE INDEX IF NOT EXISTS idx_pair_codes_expires ON pair_codes(expires_at);

-- Комментарии
COMMENT ON TABLE pair_codes IS '8-значные коды привязки роботов';
COMMENT ON COLUMN pair_codes.code IS '8-значный буквенно-цифровой код';
COMMENT ON COLUMN pair_codes.status IS 'Статус кода (pending, confirmed, expired)';
COMMENT ON COLUMN pair_codes.expires_at IS 'Время истечения кода (обычно 15 минут)';
COMMENT ON COLUMN pair_codes.confirmed_at IS 'Время подтверждения привязки';

-- =============================================================================
-- Функция автоматического обновления updated_at
-- =============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггер для robots
DROP TRIGGER IF EXISTS update_robots_updated_at ON robots;
CREATE TRIGGER update_robots_updated_at
    BEFORE UPDATE ON robots
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- Функция автоматической проверки истёкших кодов
-- =============================================================================

CREATE OR REPLACE FUNCTION expire_old_pair_codes()
RETURNS void AS $$
BEGIN
    UPDATE pair_codes
    SET status = 'expired'
    WHERE status = 'pending'
      AND expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Функция для определения онлайн-статуса роботов
-- =============================================================================

CREATE OR REPLACE FUNCTION check_robot_activity()
RETURNS void AS $$
BEGIN
    -- Роботы без активности более 5 минут помечаются как inactive
    UPDATE robots
    SET status = 'inactive'
    WHERE status = 'active'
      AND last_seen_at < NOW() - INTERVAL '5 minutes';
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Представление для удобного отображения роботов
-- =============================================================================

CREATE OR REPLACE VIEW robots_view AS
SELECT
    r.id,
    r.name,
    r.hostname,
    r.ip_address,
    r.architecture::text,
    r.status::text,
    r.description,
    r.created_at,
    r.updated_at,
    r.last_seen_at,
    CASE
        WHEN r.status = 'active' AND r.last_seen_at > NOW() - INTERVAL '1 minute' THEN 'онлайн'
        WHEN r.status = 'active' AND r.last_seen_at > NOW() - INTERVAL '5 minutes' THEN 'задержка'
        WHEN r.status = 'pending' THEN 'ожидает привязки'
        WHEN r.status = 'inactive' THEN 'неактивен'
        WHEN r.status = 'error' THEN 'ошибка'
        ELSE 'неизвестно'
    END AS status_display,
    pc.code AS last_pair_code
FROM robots r
LEFT JOIN LATERAL (
    SELECT code
    FROM pair_codes
    WHERE robot_id = r.id
    ORDER BY created_at DESC
    LIMIT 1
) pc ON true;

COMMENT ON VIEW robots_view IS 'Представление роботов с человекочитаемыми статусами';

-- =============================================================================
-- Начальные данные (опционально)
-- =============================================================================

-- Пример: демо-робот для тестирования (закомментировано)
-- INSERT INTO robots (name, hostname, ip_address, architecture, status)
-- VALUES ('demo-robot', 'demo-robot.local', '192.168.1.100', 'arm64', 'active');
