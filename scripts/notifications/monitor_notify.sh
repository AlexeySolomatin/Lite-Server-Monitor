#!/bin/bash
set -euo pipefail

# --- КОНФИГУРАЦИЯ ---
SECRETS_FILE="/etc/print-monitor/secrets.conf"
LOG_FILE="/var/log/print-monitor/alerts.log"

# 1. Проверка файла секретов
if [[ ! -f "$SECRETS_FILE" ]]; then
    echo "Ошибка: файл секретов не найден: $SECRETS_FILE" >&2
    exit 1
fi

source "$SECRETS_FILE"

# 2. Валидация переменных
required_vars=("TELEGRAM_TOKEN" "TELEGRAM_CHAT_ID" "ADMIN_EMAIL" "SMTP_FROM")
missing_vars=()

for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        missing_vars+=("$var")
    fi
done

if [[ ${#missing_vars[@]} -gt 0 ]]; then
    echo "Ошибка: не заданы следующие переменные в secrets.conf: ${missing_vars[*]}" >&2
    exit 1
fi

# 3. Определение контекста (Node Tag)
MODULE="${1:-SYSTEM}"
MESSAGE="${2:-Нет текста сообщения}"
HOSTNAME=$(hostname)

if [[ "$HOSTNAME" == *"print-node-1"* ]]; then
    NODE_TAG="[print-ha][node-1]"
elif [[ "$HOSTNAME" == *"print-node-2"* ]]; then
    NODE_TAG="[print-ha][node-2]"
else
    NODE_TAG="[print-ha][$HOSTNAME]"
fi

FULL_MSG="${NODE_TAG}[${MODULE}] ${MESSAGE}"

# Функция логирования
log_event() {
    local level="${1:-INFO}"
    local msg="${2:-}"
    mkdir -p "$(dirname "$LOG_FILE")"
    # Используем flock для защиты от повреждения лога при параллельном запуске
    ( flock -n 9
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $msg" >> "$LOG_FILE"
    ) 9>>"$LOG_FILE"
}

log_event "INFO" "$FULL_MSG"

# --- ОТПРАВКА TELEGRAM ---
# ИСПРАВЛЕНО: добавлен /bot/ и правильный синтаксис подстановки переменной
TELEGRAM_URL="https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage"

TG_RESPONSE=$(/usr/bin/curl -k -s -L -X POST "$TELEGRAM_URL" \
  -d chat_id="${TELEGRAM_CHAT_ID}" \
  --data-urlencode "text=${FULL_MSG}" 2>&1) || TG_RESPONSE="CURL_CRASH"

if [[ "$TG_RESPONSE" != *"\"ok\":true"* ]]; then
    log_event "ERROR" "Telegram API вернул ошибку. Ответ: $TG_RESPONSE"
else
    log_event "INFO" "Сообщение успешно отправлено в Telegram."
fi

# --- ОТПРАВКА EMAIL (MSMTP) ---
EMAIL_SUBJECT="PRINT-HA ALERT: ${MODULE}"

if command -v msmtp >/dev/null 2>&1; then
    # Формируем тело письма
    EMAIL_BODY=$(cat <<EOF
Subject: ${EMAIL_SUBJECT}
From: ${SMTP_FROM}
To: ${ADMIN_EMAIL}

${FULL_MSG}
EOF
)
    # Отправляем через временный файл, чтобы избежать проблем с пайпом в некоторых оболочках
    if echo "$EMAIL_BODY" | msmtp --account=yandex "$ADMIN_EMAIL" 2>/dev/null; then
        log_event "INFO" "Email успешно отправлен на ${ADMIN_EMAIL}"
    else
        log_event "ERROR" "Не удалось отправить email. Проверьте настройки msmtp."
    fi
else
    log_event "WARNING" "Утилита msmtp не найдена. Email-оповещения отключены."
fi

exit 0
