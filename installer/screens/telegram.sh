id="58291"
#!/usr/bin/env bash
# shellcheck disable=SC2034
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Экран настройки Telegram уведомлений
# Путь: installer/screens/telegram.sh
#
# Назначение:
#   Сохраняет параметры Telegram для отправки уведомлений LSM.
#
#   Пользователь может:
#       - ввести данные сейчас;
#       - выполнить настройку позже через файл секретов.
# -----------------------------------------------------------------------------

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


    echo \
        "Для работы нужны токен Telegram-бота и ID получателя."


    echo

    echo -e \
        "  ${CLR_CYAN}•${CLR_RESET} Создание бота: ${CLR_YELLOW}@BotFather${CLR_RESET}"


    echo -e \
        "  ${CLR_CYAN}•${CLR_RESET} Получение Chat ID: ${CLR_YELLOW}@userinfobot${CLR_RESET}"


    echo



    #
    # Возможность пропустить настройку
    #

    if [[ "${INSTALL_MODE:-standard}" == "standard" ]]; then


        if ! wizard_yes_no \
            "Ввести параметры Telegram сейчас?" \
            "y"; then


            echo


            echo -e \
                "${CLR_YELLOW}Настройку Telegram можно выполнить позже.${CLR_RESET}"


            echo -e \
                "Файл секретов: ${CLR_CYAN}/etc/lsm/secrets.conf${CLR_RESET}"


            return 0


        fi


    fi



    #
    # Bot Token
    #

    TG_BOT_TOKEN=""


    while [[ -z "${TG_BOT_TOKEN}" ]]; do


        wizard_input \
            "Введите токен Telegram-бота" \
            "TG_BOT_TOKEN"



        if [[ -z "${TG_BOT_TOKEN}" ]]; then


            echo -e \
                "${CLR_RED}Токен не может быть пустым.${CLR_RESET}"


        fi


    done



    #
    # Chat ID
    #

    TG_CHAT_ID=""


    while [[ -z "${TG_CHAT_ID}" ]]; do


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
