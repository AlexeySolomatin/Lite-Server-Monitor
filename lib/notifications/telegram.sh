#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Модуль отправки уведомлений в Telegram Bot API
# Путь: lib/notifications/telegram.sh
# ==============================================================================

set -Eeuo pipefail

# Загрузка файлов конфигурации и секретов
CONFIG_FILE="${NOTIFICATIONS_FILE:-/etc/lsm/notifications.conf}"
SECRETS_FILE="${SECRETS_FILE:-/etc/lsm/secrets.conf}"

if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"
fi

if [[ -f "${SECRETS_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${SECRETS_FILE}"
fi

# Безопасное считывание параметров вызова
TITLE="${1:-Уведомление LSM}"
MESSAGE="${2:-}"

# Если ключи авторизации не заданы — завершаем работу без ошибки
if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]]; then
    exit 0
fi

# Проверка наличия curl в системе
if ! command -v curl >/dev/null 2>&1; then
    if declare -f log_error >/dev/null 2>&1; then
        log_error "TELEGRAM" "Утилита curl не найдена. Отправка отменена."
    else
        echo "Ошибка: Утилита curl не найдена." >&2
    fi
    exit 1
fi

#
# Экранирование спецсимволов для безопасной передачи в parse_mode=HTML
#
escape_html() {
    local str="${1:-}"
    str="${str//&/&amp;}"
    str="${str//</&lt;}"
    str="${str//>/&gt;}"
    printf '%s' "${str}"
}

clean_title="$(escape_html "${TITLE}")"
clean_message="$(escape_html "${MESSAGE}")"

# Формирование итогового текста с корректным переносом строки
formatted_text=""
printf -v formatted_text "<b>%s</b>\n\n%s" "${clean_title}" "${clean_message}"

if declare -f log_info >/dev/null 2>&1; then
    log_info "TELEGRAM" "Отправка уведомления в чат ${TELEGRAM_CHAT_ID}..."
fi

# Отправка сообщения в Telegram API
curl -fsS \
    --connect-timeout 10 \
    --max-time 30 \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "parse_mode=HTML" \
    --data-urlencode "text=${formatted_text}" \
    >/dev/null
