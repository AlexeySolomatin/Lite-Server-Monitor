#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Installation Wizard
# -----------------------------------------------------------------------------

readonly LSM_SCREENS_DIR="${LSM_ROOT}/installer/screens"

# shellcheck source=/dev/null
source "${LSM_SCREENS_DIR}/common.sh"
# shellcheck source=/dev/null
source "${LSM_SCREENS_DIR}/welcome.sh"
# shellcheck source=/dev/null
source "${LSM_SCREENS_DIR}/install_mode.sh"
# shellcheck source=/dev/null
source "${LSM_SCREENS_DIR}/modules.sh"
# shellcheck source=/dev/null
source "${LSM_SCREENS_DIR}/notifications.sh"
# shellcheck source=/dev/null
source "${LSM_SCREENS_DIR}/telegram.sh"
# shellcheck source=/dev/null
source "${LSM_SCREENS_DIR}/smtp.sh"
# shellcheck source=/dev/null
source "${LSM_SCREENS_DIR}/ups.sh"
# shellcheck source=/dev/null
source "${LSM_SCREENS_DIR}/summary.sh"

run_install_wizard() {
    wizard_init_tty

    screen_welcome
    screen_install_mode

    # Если выбрана быстрая установка — ставим дефолтные модули
    if [[ "${INSTALL_MODE}" == "preset" ]]; then
        SELECTED_MODULES=("disk" "system" "temperature" "smart" "login")
    else
        screen_modules
    fi

    screen_notifications

    # Настройка Telegram
    if [[ "${NOTIFICATION_METHOD}" == "telegram" ]] || [[ "${NOTIFICATION_METHOD}" == "both" ]]; then
        screen_telegram
    fi

    # Настройка SMTP
    if [[ "${NOTIFICATION_METHOD}" == "email" ]] || [[ "${NOTIFICATION_METHOD}" == "both" ]]; then
        screen_smtp
    fi

    # Настройка UPS
    screen_ups

    screen_summary

    # Экспортируем переменные в окружение процесса установки
    export INSTALL_MODE SELECTED_MODULES NOTIFICATION_METHOD
    export TG_BOT_TOKEN TG_CHAT_ID
    export SMTP_PROFILE SMTP_SERVER SMTP_PORT SMTP_TLS SMTP_USERNAME SMTP_PASSWORD SMTP_FROM
    export INSTALL_UPS UPS_PROFILE
}
