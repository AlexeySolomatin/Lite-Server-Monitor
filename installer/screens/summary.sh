#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Installation Summary Screen
# -----------------------------------------------------------------------------

set -Eeuo pipefail

screen_summary() {
    wizard_header

    echo -e "${CLR_BOLD}Сводный отчет параметров установки:${CLR_RESET}"
    echo "Пожалуйста, проверьте выбранную конфигурацию перед запуском инсталляции."
    echo

    echo -e "  ${CLR_CYAN}Режим установки:${CLR_RESET}      ${INSTALL_MODE:-preset}"
    echo -e "  ${CLR_CYAN}Канал уведомлений:${CLR_RESET}    ${NOTIFICATION_METHOD:-none}"

    if [[ "${NOTIFICATION_METHOD:-none}" == "telegram" ]] || [[ "${NOTIFICATION_METHOD:-none}" == "both" ]]; then
        echo -e "  ${CLR_CYAN}Telegram Chat ID:${CLR_RESET}     ${TG_CHAT_ID:-не указан}"
    fi

    if [[ "${NOTIFICATION_METHOD:-none}" == "email" ]] || [[ "${NOTIFICATION_METHOD:-none}" == "both" ]]; then
        echo -e "  ${CLR_CYAN}Профиль SMTP:${CLR_RESET}         ${SMTP_PROFILE:-custom} (${SMTP_USER:-N/A})"
        echo -e "  ${CLR_CYAN}Получатель Email:${CLR_RESET}     ${ALERT_EMAIL:-не указан}"
    fi

    if [[ "${INSTALL_UPS:-false}" == "true" ]]; then
        echo -e "  ${CLR_CYAN}Мониторинг ИБП:${CLR_RESET}       Включен (${UPS_PROFILE:-default})"
    else
        echo -e "  ${CLR_CYAN}Мониторинг ИБП:${CLR_RESET}       Отключен"
    fi

    echo
    echo -e "${CLR_BOLD}Выбранные модули проверки:${CLR_RESET}"

    if [[ ${#SELECTED_MODULES[@]} -gt 0 ]]; then
        for module in "${SELECTED_MODULES[@]}"; do
            echo -e "  ${CLR_GREEN}•${CLR_RESET} ${module}"
        done
    else
        echo -e "  ${CLR_YELLOW}• Базовый системный модуль (system)${CLR_RESET}"
    fi

    echo

    if ! wizard_yes_no "Приступить к инсталляции системы с этими параметрами?" "y"; then
        echo
        echo -e "${CLR_YELLOW}Установка отменена пользователем.${CLR_RESET}"
        exit 0
    fi

    echo
    echo -e "${CLR_GREEN}✓ Параметры подтверждены. Переход к процессу установки...${CLR_RESET}"
    sleep 1
}
