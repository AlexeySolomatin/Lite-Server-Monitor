#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Экран итоговой проверки установки
# Путь: installer/screens/summary.sh
#
# Назначение:
#   Показывает итоговые параметры перед запуском установки:
#
#   - режим установки;
#   - уведомления;
#   - UPS;
#   - ежедневный отчет;
#   - выбранные модули.
# ==============================================================================


set -Eeuo pipefail



#
# Итоговая информация перед установкой
#

screen_summary()
{

    wizard_header



    echo -e "${CLR_BOLD}Сводная информация перед установкой:${CLR_RESET}"

    echo "Проверьте выбранные параметры перед началом установки."

    echo



    #
    # Основные параметры
    #

    echo -e \
        "  ${CLR_CYAN}Режим установки:${CLR_RESET}      ${INSTALL_MODE:-standard}"


    echo -e \
        "  ${CLR_CYAN}Уведомления:${CLR_RESET}          ${NOTIFICATION_METHOD:-none}"



    #
    # Telegram
    #

    if [[ "${NOTIFICATION_METHOD:-none}" == "telegram" ]] || \
       [[ "${NOTIFICATION_METHOD:-none}" == "both" ]]; then


        if [[ -n "${TG_CHAT_ID:-}" ]]; then


            echo -e \
                "  ${CLR_CYAN}Telegram Chat ID:${CLR_RESET}     ${TG_CHAT_ID}"


        else


            echo -e \
                "  ${CLR_CYAN}Telegram:${CLR_RESET}             настройка позже"


        fi


    fi



    #
    # Email
    #

    if [[ "${NOTIFICATION_METHOD:-none}" == "email" ]] || \
       [[ "${NOTIFICATION_METHOD:-none}" == "both" ]]; then


        if [[ -n "${SMTP_USER:-}" ]]; then


            echo -e \
                "  ${CLR_CYAN}SMTP профиль:${CLR_RESET}         ${SMTP_PROFILE:-manual}"


            echo -e \
                "  ${CLR_CYAN}Email получателя:${CLR_RESET}     ${ALERT_EMAIL:-не указан}"


        else


            echo -e \
                "  ${CLR_CYAN}Email:${CLR_RESET}               настройка позже"


        fi


    fi



    #
    # UPS
    #

    if [[ "${INSTALL_UPS:-false}" == "true" ]]; then


        echo -e \
            "  ${CLR_CYAN}Мониторинг ИБП:${CLR_RESET}       включен (${UPS_PROFILE:-default})"


    else


        echo -e \
            "  ${CLR_CYAN}Мониторинг ИБП:${CLR_RESET}       отключен"


    fi



    #
    # Ежедневный отчет
    #

    if [[ "${DAILY_REPORT_ENABLED:-false}" == "true" ]]; then


        echo -e \
            "  ${CLR_CYAN}Ежедневный отчет:${CLR_RESET}     включен (${DAILY_REPORT_TIME:-09:00})"


    else


        echo -e \
            "  ${CLR_CYAN}Ежедневный отчет:${CLR_RESET}     отключен"


    fi



    echo



    #
    # Модули
    #

    echo -e "${CLR_BOLD}Устанавливаемые модули:${CLR_RESET}"



    #
    # Безопасно определяем количество выбранных модулей.
    #
    # summary.sh работает с set -u, поэтому прямое обращение:
    #
    #   ${#SELECTED_MODULES[@]}
    #
    # вызовет ошибку, если массив еще не был создан.
    #

    local module_count=0



    if declare -p SELECTED_MODULES >/dev/null 2>&1; then

        module_count="${#SELECTED_MODULES[@]}"

    fi



    if (( module_count > 0 )); then


        local module


        for module in "${SELECTED_MODULES[@]}"; do


            echo -e \
                "  ${CLR_GREEN}•${CLR_RESET} ${module}"


        done


    else


        echo -e \
            "  ${CLR_YELLOW}• Модули не выбраны${CLR_RESET}"


    fi



    echo



    #
    # Подтверждение
    #

    if ! wizard_yes_no \
        "Начать установку Lite Server Monitor?" \
        "y"; then


        echo

        echo -e \
            "${CLR_YELLOW}Установка отменена пользователем.${CLR_RESET}"


        exit 0


    fi



    echo

    echo -e \
        "${CLR_GREEN}✓ Параметры подтверждены. Начинается установка...${CLR_RESET}"


    sleep 1

}
