#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Telegram Notification
# -----------------------------------------------------------------------------

set -Eeuo pipefail


CONFIG_FILE="${NOTIFICATIONS_FILE:-/etc/lsm/notifications.conf}"

SECRETS_FILE="${SECRETS_FILE:-/etc/lsm/secrets.conf}"


[[ -f "${CONFIG_FILE}" ]] &&
    source "${CONFIG_FILE}"



TITLE="$1"
MESSAGE="$2"



if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]]; then
    exit 0
fi


if [[ -z "${TELEGRAM_CHAT_ID:-}" ]]; then
    exit 0
fi



curl -fsS \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "parse_mode=HTML" \
    --data-urlencode \
    "text=<b>${TITLE}</b>%0A${MESSAGE}" \
    >/dev/null
