#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Экран настройки Email (SMTP)
#
# Путь:
#   installer/screens/smtp.sh
#
# Назначение:
#   Настройка SMTP для отправки уведомлений и отчетов LSM.
#
#   Поддерживает:
#       - стандартные профили Gmail/Yandex;
#       - ручную настройку SMTP;
#       - отложенную настройку через secrets.conf.
# ==============================================================================

set -Eeuo pipefail



#
# Параметры SMTP
#

EMAIL_ENABLED="false"

SMTP_PROFILE=""
SMTP_SERVER=""
SMTP_PORT=""
SMTP_TLS=""

SMTP_USER=""
SMTP_PASS=""

SMTP_FROM=""
ALERT_EMAIL=""



#
# Настройка SMTP
#

screen_smtp()
{

    wizard_header



    echo -e \
        "${CLR_BOLD}Настройка Email уведомлений (SMTP):${CLR_RESET}"


    echo

    echo "Параметры SMTP используются для отправки:"
    echo "  - аварийных уведомлений;"
    echo "  - ежедневных отчетов."


    echo



    #
    # В стандартной установке можно пропустить настройку
    #

    if [[ "${INSTALL_MODE:-standard}" == "standard" ]]; then


        if ! wizard_yes_no \
            "Ввести параметры Email сейчас?" \
            "y"; then


            EMAIL_ENABLED="false"

            SMTP_PROFILE=""
            SMTP_SERVER=""
            SMTP_PORT=""
            SMTP_TLS=""
            SMTP_USER=""
            SMTP_PASS=""
            SMTP_FROM=""
            ALERT_EMAIL=""


            echo


            echo -e \
                "${CLR_YELLOW}Настройка Email пропущена.${CLR_RESET}"


            echo -e \
                "Позже параметры можно добавить в файл:"


            echo -e \
                "${CLR_CYAN}/etc/lsm/secrets.conf${CLR_RESET}"


            return 0


        fi


    fi



    EMAIL_ENABLED="true"



    #
    # Выбор SMTP профиля
    #

    echo -e "${CLR_CYAN}Выберите SMTP профиль:${CLR_RESET}"

    echo

    echo -e "  ${CLR_CYAN}1)${CLR_RESET} Gmail (587 STARTTLS)"
    echo -e "  ${CLR_CYAN}2)${CLR_RESET} Yandex (465 SSL/TLS)"
    echo -e "  ${CLR_CYAN}3)${CLR_RESET} Ручная настройка"


    echo



    while true
    do


        read -rp \
            "$(echo -e "${CLR_BOLD}Выберите вариант [1-3]${CLR_RESET} [${CLR_YELLOW}1${CLR_RESET}]: ")" \
            answer


        answer="${answer:-1}"



        case "${answer}" in


            1)

                SMTP_PROFILE="gmail"
                SMTP_SERVER="smtp.gmail.com"
                SMTP_PORT="587"
                SMTP_TLS="on"

                break

                ;;



            2)

                SMTP_PROFILE="yandex"
                SMTP_SERVER="smtp.yandex.ru"
                SMTP_PORT="465"
                SMTP_TLS="on"

                break

                ;;



            3)

                SMTP_PROFILE="manual"


                wizard_input \
                    "SMTP сервер" \
                    "SMTP_SERVER"


                wizard_input \
                    "SMTP порт" \
                    "SMTP_PORT" \
                    "587"


                wizard_input \
                    "Использовать TLS (on/off)" \
                    "SMTP_TLS" \
                    "on"


                break

                ;;



            *)

                echo -e \
                    "${CLR_RED}Введите число от 1 до 3.${CLR_RESET}"

                ;;


        esac


    done



    echo



    #
    # Учетные данные SMTP
    #

    while [[ -z "${SMTP_USER}" ]]
    do


        wizard_input \
            "Логин SMTP (Email)" \
            "SMTP_USER"


        if [[ -z "${SMTP_USER}" ]]; then

            echo -e \
                "${CLR_RED}Логин не может быть пустым.${CLR_RESET}"

        fi


    done



    while [[ -z "${SMTP_PASS}" ]]
    do


        wizard_mask_input \
            "Пароль приложения SMTP" \
            "SMTP_PASS"


        if [[ -z "${SMTP_PASS}" ]]; then

            echo -e \
                "${CLR_RED}Пароль не может быть пустым.${CLR_RESET}"

        fi


    done



    #
    # Адреса отправителя и получателя
    #

    wizard_input \
        "Email отправителя" \
        "SMTP_FROM" \
        "${SMTP_USER}"



    while [[ -z "${ALERT_EMAIL}" ]]
    do


        wizard_input \
            "Email получателя уведомлений" \
            "ALERT_EMAIL" \
            "${SMTP_USER}"


        if [[ -z "${ALERT_EMAIL}" ]]; then

            echo -e \
                "${CLR_RED}Email получателя не может быть пустым.${CLR_RESET}"

        fi


    done



    echo


    echo -e \
        "${CLR_GREEN}✓ Параметры Email SMTP сохранены.${CLR_RESET}"


}
