#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Экран настройки ежедневных отчетов
#
# Путь:
#   installer/screens/daily_report.sh
#
# Назначение:
#   Управляет формированием ежедневного отчета состояния сервера.
#
#   Стандартный режим:
#       отчет включается автоматически.
#
#   Настраиваемый режим:
#       пользователь выбирает включить или отключить.
# ==============================================================================

set -Eeuo pipefail


#
# Значения по умолчанию
#

DAILY_REPORT_ENABLED=false
DAILY_REPORT_TIME="09:00"



screen_daily_report()
{

    wizard_header


    #
    # Стандартная установка
    #

    if [[ "${INSTALL_MODE:-standard}" == "standard" ]]; then


        DAILY_REPORT_ENABLED=true
        DAILY_REPORT_TIME="09:00"


        echo -e \
            "${CLR_BOLD}Ежедневный отчет:${CLR_RESET}"


        echo


        echo -e \
            "${CLR_GREEN}✓ Ежедневный отчет включен автоматически.${CLR_RESET}"


        echo -e \
            "Время отправки: ${CLR_CYAN}${DAILY_REPORT_TIME}${CLR_RESET}"


        return 0

    fi



    #
    # Настраиваемый режим
    #

    echo -e \
        "${CLR_BOLD}Настройка ежедневного отчета:${CLR_RESET}"


    echo \
        "LSM может автоматически отправлять ежедневную сводку состояния сервера."


    echo


    if ! wizard_yes_no \
        "Включить ежедневный отчет?" \
        "y"; then


        DAILY_REPORT_ENABLED=false
        DAILY_REPORT_TIME=""


        return 0

    fi



    DAILY_REPORT_ENABLED=true



    wizard_input \
        "Время отправки отчета (HH:MM)" \
        "DAILY_REPORT_TIME" \
        "09:00"



    echo


    echo -e \
        "${CLR_GREEN}✓ Ежедневный отчет включен.${CLR_RESET}"


    echo -e \
        "Время отправки: ${CLR_CYAN}${DAILY_REPORT_TIME}${CLR_RESET}"

}
