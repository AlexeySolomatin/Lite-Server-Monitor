#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Экран настройки Telegram уведомлений
#
# Путь:
#   installer/screens/telegram.sh
#
# Назначение:
#   Получение параметров Telegram-бота для отправки уведомлений LSM.
#
#   Поддерживает:
#       - ввод данных во время установки;
#       - пропуск настройки с последующим заполнением secrets.conf.
# ==============================================================================

set -Eeuo pipefail



#
# Параметры Telegram
#

TG_BOT_TOKEN=""

TG_CHAT_ID=""



#
# Настройка Telegram
#

screen_telegram()
{

    wizard_header



    echo -e \
        "${CLR_BOLD}Настройка уведомлений Telegram:${CLR_RESET}"


    echo

    echo "Для работы Telegram необходимы:"


    echo -e \
        "  ${CLR_CYAN}•${CLR_RESET} Токен Telegram-бота (${CLR_YELLOW}@BotFather${CLR_RESET})"


    echo -e \
        "  ${CLR_CYAN}•${CLR_RESET} Chat ID получателя"


    echo



    #
    # В стандартной установке разрешаем пропустить настройку
    #

    if [[ "${INSTALL_MODE:-standard}" == "standard" ]]; then


        if ! wizard_yes_no \
            "Ввести параметры Telegram сейчас?" \
            "y"; then


            TG_BOT_TOKEN=""
            TG_CHAT_ID=""


            echo


            echo -e \
                "${CLR_YELLOW}Настройка Telegram пропущена.${CLR_RESET}"


            echo -e \
                "Позже параметры можно добавить в файл:"


            echo -e \
                "${CLR_CYAN}/etc/lsm/secrets.conf${CLR_RESET}"


            return 0


        fi


    fi



    #
    # Ввод Bot Token
    #

    while [[ -z "${TG_BOT_TOKEN}" ]]
    do


        wizard_input \
            "Введите токен Telegram-бота" \
            "TG_BOT_TOKEN"


        if [[ -z "${TG_BOT_TOKEN}" ]]; then


            echo -e \
                "${CLR_RED}Токен не может быть пустым.${CLR_RESET}"


        fi


    done



    #
    # Ввод Chat ID
    #

    while [[ -z "${TG_CHAT_ID}" ]]
    do


        wizard_input \
            "Введите Chat ID получателя" \
            "TG_CHAT_ID"


        if [[ -z "${TG_CHAT_ID}" ]]; then


            echo -e \
                "${CLR_RED}Chat ID не может быть пустым.${CLR_RESET}"


        fi


    done



    echo


    echo -e \
        "${CLR_GREEN}✓ Параметры Telegram сохранены.${CLR_RESET}"


}
