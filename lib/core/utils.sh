#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Библиотека вспомогательных утилит
# Путь: lib/core/utils.sh
# ==============================================================================

set -Eeuo pipefail

# Защита от повторного подключения файла
[[ -n "${LSM_UTILS_LOADED:-}" ]] && return 0
readonly LSM_UTILS_LOADED=1

#
# Получение текущего штампа времени в формате YYYY-MM-DD HH:MM:SS
#
current_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

#
# Удаление начальных и конечных пробельных символов (Pure Bash Trim)
#
trim() {
    local value="$*"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    printf '%s' "${value}"
}

#
# Генерация случайной буквенно-цифровой строки (по умолчанию 16 символов)
#
random_string() {
    local length="${1:-16}"

    # LC_ALL=C обеспечивает стабильную работу tr под любой локалью
    # Группа { ... } || true предотвращает аварийный выход из-за SIGPIPE в set -e
    { LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null || true; } | head -c "${length}"
}
