#!/bin/bash

# Hook: Проверяет, нужно ли обновить wiki перед коммитом
# Срабатывает на git commit, анализирует staged файлы

# Читаем JSON input от Cursor
input=$(cat)
command=$(echo "$input" | jq -r '.command // empty')

# Проверяем, что это git commit
if [[ ! "$command" =~ ^git\ commit ]]; then
    echo '{"continue": true, "permission": "allow"}'
    exit 0
fi

# Получаем список staged файлов
staged_files=$(git diff --cached --name-only 2>/dev/null)

if [ -z "$staged_files" ]; then
    echo '{"continue": true, "permission": "allow"}'
    exit 0
fi

# Файлы/паттерны, которые могут влиять на документацию
doc_relevant_patterns=(
    "docker-compose"
    "Dockerfile"
    ".env"
    "config.py"
    "requirements.txt"
    "package.json"
    "install.sh"
    "routers/"
    "api/"
    ".github/workflows"
)

# Проверяем, есть ли среди staged файлов потенциально важные для документации
relevant_files=""
for file in $staged_files; do
    for pattern in "${doc_relevant_patterns[@]}"; do
        if [[ "$file" == *"$pattern"* ]]; then
            relevant_files="$relevant_files $file"
            break
        fi
    done
done

# Проверяем, есть ли wiki среди staged (уже обновляется)
wiki_staged=$(echo "$staged_files" | grep "^wiki/" || true)

if [ -n "$relevant_files" ] && [ -z "$wiki_staged" ]; then
    # Есть изменения в коде, но wiki не обновляется — предупреждаем
    cat << EOF
{
  "continue": true,
  "permission": "ask",
  "user_message": "Изменены файлы, которые могут влиять на документацию:$relevant_files\n\nWiki не обновлена. Проверить документацию перед коммитом?",
  "agent_message": "Обнаружены изменения в файлах, которые часто требуют обновления документации:$relevant_files\n\nПеред коммитом рекомендуется проверить wiki/ на актуальность. Используй skill 'sync-wiki-with-code' для анализа."
}
EOF
else
    echo '{"continue": true, "permission": "allow"}'
fi
