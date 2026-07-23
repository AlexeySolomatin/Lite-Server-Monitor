#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Installation Wizard Master Controller
# -----------------------------------------------------------------------------

set -Eeuo pipefail

# Определение корня LSM при автономном запуске
LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
readonly LSM_SCREENS_DIR="${LSM_ROOT}/installer/screens"

# Безопасная подгрузка экранов UI
load_screen() {
    local screen_file="${1}"
    if [[ -f "${screen_file}" ]]; then
        # shellcheck source=/dev/null
        source "${screen_file}"
    else
        echo -e "\e[31m[ERROR]\e[0m Required wizard screen file not found: ${screen_file}" >&2
        exit 1
    fi
}

load_screen "${LSM_SCREENS_DIR}/common.sh"
load_screen "${LSM_SCREENS_DIR}/welcome.sh"
load_screen "${LSM_SCREENS_DIR}/install_mode.sh"
load_screen "${LSM_SCREENS_DIR}/modules.sh"
load_screen "${LSM_SCREENS_DIR}/notifications.sh"
load_screen "${LSM_SCREENS_DIR}/telegram.sh"
load_screen "${LSM_SCREENS_DIR}/smtp.sh"
load_screen "${LSM_SCREENS_DIR}/ups.sh"
load_screen "${LSM_SCREENS_DIR}/summary.sh"

run_install_wizard() {
    wizard_init_tty

    screen_welcome
    screen_install_mode

    # Если выбрана быстрая установка — ставим стандартный пресет модулей
    if [[ "${INSTALL_MODE:-preset}" == "preset" ]]; then
        SELECTED_MODULES=("disk" "system" "temperature" "smart" "login")
    else
        screen_modules
    fi

    screen_notifications

    # Настройка Telegram
    if [[ "${NOTIFICATION_METHOD:-none}" == "telegram" ]] || [[ "${NOTIFICATION_METHOD:-none}" == "both" ]]; then
        screen_telegram
    fi

    # Настройка SMTP
    if [[ "${NOTIFICATION_METHOD:-none}" == "email" ]] || [[ "${NOTIFICATION_METHOD:-none}" == "both" ]]; then
        screen_smtp
    fi

    # Настройка UPS
    screen_ups

    screen_summary

    # Экспортируем переменные в окружение процесса установки
    export INSTALL_MODE NOTIFICATION_METHOD
    export TG_BOT_TOKEN TG_CHAT_ID
    export EMAIL_ENABLED SMTP_PROFILE SMTP_SERVER SMTP_PORT SMTP_TLS SMTP_USER SMTP_PASS SMTP_FROM ALERT_EMAIL
    export INSTALL_UPS UPS_PROFILE
    
    # Сохраняем и экспортируем массив выбранных модулей
    export SELECTED_MODULES
    export SELECTED_MODULES_STR="${SELECTED_MODULES[*]}"
}
