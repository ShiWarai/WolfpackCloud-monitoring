#!/bin/bash
set -e

echo "=== WolfpackCloud Monitoring API ==="

# Ожидание готовности PostgreSQL (пробуем подключиться через python)
echo "Ожидание PostgreSQL..."
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if python -c "
import asyncio
import asyncpg
import os

async def check():
    try:
        url = os.environ.get('DATABASE_URL', '')
        # Преобразуем asyncpg URL
        url = url.replace('postgresql+asyncpg://', 'postgresql://')
        conn = await asyncpg.connect(url)
        await conn.close()
        return True
    except Exception:
        return False

exit(0 if asyncio.run(check()) else 1)
" 2>/dev/null; then
        echo "PostgreSQL готов"
        break
    fi
    attempt=$((attempt + 1))
    echo "Попытка $attempt/$max_attempts..."
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo "WARN: Не удалось подключиться к PostgreSQL, продолжаем..."
fi

# Запуск миграций Alembic
echo "Запуск миграций..."
if alembic upgrade head 2>&1; then
    echo "Миграции успешно применены"
else
    echo "Ошибка миграций или уже применены, продолжаем..."
fi

# Создание администратора по умолчанию
echo "Проверка администратора..."
python -c "
import asyncio
import os
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=['bcrypt'], deprecated='auto')

async def create_admin():
    import asyncpg
    
    url = os.environ.get('DATABASE_URL', '')
    url = url.replace('postgresql+asyncpg://', 'postgresql://')
    
    email = os.environ.get('DEFAULT_ADMIN_EMAIL', 'admin@wolfpackcloud.dev')
    password = os.environ.get('DEFAULT_ADMIN_PASSWORD', 'admin')
    name = os.environ.get('DEFAULT_ADMIN_NAME', 'Administrator')
    
    conn = await asyncpg.connect(url)
    
    # Проверяем, есть ли уже админ
    existing = await conn.fetchrow('SELECT id FROM users WHERE email = \$1', email)
    if existing:
        print(f'Администратор {email} уже существует')
        await conn.close()
        return
    
    # Создаём админа
    hashed = pwd_context.hash(password)
    await conn.execute('''
        INSERT INTO users (email, hashed_password, name, role, is_active, created_at, updated_at)
        VALUES (\$1, \$2, \$3, 'admin', true, NOW(), NOW())
    ''', email, hashed, name)
    
    print(f'Администратор создан: {email}')
    await conn.close()

asyncio.run(create_admin())
" 2>&1 || echo "Не удалось создать администратора, возможно уже существует"

echo "Запуск приложения..."
exec "$@"
