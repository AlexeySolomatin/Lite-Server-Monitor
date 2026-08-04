#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Экран итоговой проверки установки
# Путь: installer/screens/summary.sh
#
# Назначение:
#   Показывает пользователю все выбранные параметры перед установкой:
#   - режим установки;
#   - уведомления;
#   - UPS;
#   - ежедневные отчеты;
#   - выбранные модули.
# -----------------------------------------------------------------------------

set -Eeuo pipefail



#
# Экран итоговой информации
#

screen_summary()
{

    wizard_header



    echo -e "${CLR_BOLD}Сводная информация перед установкой:${CLR_RESET}"

    echo "Проверьте выбранные параметры перед запуском установки."

    echo



    #
    # Основные параметры
    #

    echo -e \
        "  ${CLR_CYAN}Режим установки:${CLR_RESET}      ${INSTALL_MODE:-standard}"


    echo -e \
        "  ${CLR_CYAN}Канал уведомлений:${CLR_RESET}    ${NOTIFICATION_METHOD:-none}"



    #
    # Telegram
    #

    if [[ "${NOTIFICATION_METHOD:-none}" == "telegram" ]] || \
       [[ "${NOTIFICATION_METHOD:-none}" == "both" ]]; then


        echo -e \
            "  ${CLR_CYAN}Telegram Chat ID:${CLR_RESET}     ${TG_CHAT_ID:-не указан}"


    fi



    #
    # Email
    #

    if [[ "${NOTIFICATION_METHOD:-none}" == "email" ]] || \
       [[ "${NOTIFICATION_METHOD:-none}" == "both" ]]; then


        echo -e \
            "  ${CLR_CYAN}SMTP профиль:${CLR_RESET}         ${SMTP_PROFILE:-custom}"


        echo -e \
            "  ${CLR_CYAN}Получатель Email:${CLR_RESET}     ${ALERT_EMAIL:-не указан}"


    fi



    #
    # UPS
    #

    if [[ "${INSTALL_UPS:-false}" == "true" ]]; then


        echo -e \
            "  ${CLR_CYAN}Мониторинг ИБП:${CLR_RESET}       Включен"


    else


        echo -e \
            "  ${CLR_CYAN}Мониторинг ИБП:${CLR_RESET}       Отключен"


    fi



    #
    # Ежедневный отчет
    #

    if [[ "${DAILY_REPORT_ENABLED:-false}" == "true" ]]; then


        echo -e \
            "  ${CLR_CYAN}Ежедневный отчет:${CLR_RESET}     Включен (${DAILY_REPORT_TIME:-09:00})"


    else


        echo -e \
            "  ${CLR_CYAN}Ежедневный отчет:${CLR_RESET}     Отключен"


    fi



    echo



    #
    # Выбранные модули
    #

    echo -e "${CLR_BOLD}Устанавливаемые модули:${CLR_RESET}"


    if [[ ${#SELECTED_MODULES[@]} -gt 0 ]]; then


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
    # Подтверждение установки
    #

    if ! wizard_yes_no \
        "Начать установку Lite Server Monitor с указанными параметрами?" \
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
