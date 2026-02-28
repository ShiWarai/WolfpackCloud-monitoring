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

echo "Запуск приложения..."
exec "$@"
