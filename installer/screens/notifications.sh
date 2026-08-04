#!/usr/bin/env bash
# shellcheck disable=SC2034
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Экран настройки уведомлений
# Путь: installer/screens/notifications.sh
#
# Назначение:
#   Настройка способов отправки уведомлений LSM.
#
#   В стандартном режиме:
#       пользователь только выбирает:
#       - настроить сейчас;
#       - настроить позже.
#
#   В пользовательском режиме:
#       доступен выбор Telegram / Email.
# -----------------------------------------------------------------------------

set -Eeuo pipefail



#
# Канал уведомлений по умолчанию
#

NOTIFICATION_METHOD="none"



#
# Экран настройки уведомлений
#

screen_notifications()
{


    wizard_header



    #
    # Стандартная установка
    #

    if [[ "${INSTALL_MODE:-standard}" == "standard" ]]; then


        echo -e \
            "${CLR_BOLD}Настройка уведомлений:${CLR_RESET}"


        echo

        echo "Настроить уведомления сейчас?"

        echo

        echo -e \
            "  ${CLR_CYAN}1)${CLR_RESET} Настроить сейчас"


        echo -e \
            "  ${CLR_CYAN}2)${CLR_RESET} Настроить позже"


        echo



        while true; do


            read -rp \
                "$(echo -e "${CLR_BOLD}Выберите вариант [1-2]${CLR_RESET} [${CLR_YELLOW}1${CLR_RESET}]: ")" \
                answer



            answer="${answer:-1}"



            case "${answer}" in


                1)


                    NOTIFICATION_METHOD="telegram"

                    break

                    ;;


                2)


                    NOTIFICATION_METHOD="none"

                    echo

                    echo -e \
                        "${CLR_YELLOW}Настройку можно выполнить позже.${CLR_RESET}"


                    echo -e \
                        "Файл секретов: ${CLR_CYAN}/etc/lsm/secrets.conf${CLR_RESET}"


                    break

                    ;;


                *)


                    echo -e \
                        "${CLR_RED}Введите 1 или 2.${CLR_RESET}"


                    ;;


            esac


        done



        return 0


    fi



    #
    # Пользовательская установка
    #

    echo -e \
        "${CLR_BOLD}Выбор способа отправки уведомлений:${CLR_RESET}"


    echo "Укажите, куда система будет отправлять алерты и отчеты."

    echo


    echo -e \
        "  ${CLR_CYAN}1)${CLR_RESET} Без уведомлений"


    echo -e \
        "  ${CLR_CYAN}2)${CLR_RESET} Telegram-бот ${CLR_YELLOW}(рекомендуется)${CLR_RESET}"


    echo -e \
        "  ${CLR_CYAN}3)${CLR_RESET} Email (SMTP)"


    echo -e \
        "  ${CLR_CYAN}4)${CLR_RESET} Telegram + Email"


    echo



    while true; do


        read -rp \
            "$(echo -e "${CLR_BOLD}Выберите вариант [1-4]${CLR_RESET} [${CLR_YELLOW}2${CLR_RESET}]: ")" \
            answer



        answer="${answer:-2}"



        case "${answer}" in


            1)


                NOTIFICATION_METHOD="none"

                break

                ;;


            2)


                NOTIFICATION_METHOD="telegram"

                break

                ;;


            3)


                NOTIFICATION_METHOD="email"

                break

                ;;


            4)


                NOTIFICATION_METHOD="both"

                break

                ;;


            *)


                echo -e \
                    "${CLR_RED}Введите число от 1 до 4.${CLR_RESET}"


                ;;


        esac


    done


}
