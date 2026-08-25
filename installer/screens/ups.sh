#!/usr/bin/env bash
# shellcheck disable=SC2034
# ==============================================================================
# Lite Server Monitor (LSM)
# Экран настройки мониторинга ИБП
#
# Путь:
#   installer/screens/ups.sh
#
# Назначение:
#   Управляет включением мониторинга ИБП через apcupsd.
#
#   Стандартная установка:
#       мониторинг ИБП включается автоматически.
#
#   Настраиваемая установка:
#       пользователь выбирает включать или нет.
# ==============================================================================

set -Eeuo pipefail



#
# Параметры ИБП по умолчанию
#

INSTALL_UPS=false

UPS_PROFILE=""



#
# Экран настройки ИБП
#

screen_ups()
{


    wizard_header



    #
    # Стандартная установка
    #

    if [[ "${INSTALL_MODE:-standard}" == "standard" ]]; then


        INSTALL_UPS=true

        UPS_PROFILE="default"



        echo -e \
            "${CLR_BOLD}Мониторинг ИБП:${CLR_RESET}"


        echo

        echo -e \
            "${CLR_GREEN}✓ Мониторинг ИБП включен автоматически.${CLR_RESET}"


        echo -e \
            "Профиль: ${CLR_CYAN}${UPS_PROFILE}${CLR_RESET}"


        return 0


    fi



    #
    # Настраиваемая установка
    #

    echo -e \
        "${CLR_BOLD}Настройка мониторинга ИБП (APC UPS):${CLR_RESET}"


    echo \
        "Отслеживание заряда батареи, питания и состояния ИБП."


    echo



    if ! wizard_yes_no \
        "Включить мониторинг ИБП?" \
        "n"; then


        INSTALL_UPS=false

        UPS_PROFILE=""


        return 0


    fi



    INSTALL_UPS=true



    echo

    echo -e \
        "  ${CLR_CYAN}1)${CLR_RESET} APC стандартный профиль (apcupsd)"


    echo -e \
        "  ${CLR_CYAN}2)${CLR_RESET} Настроить параметры позже"


    echo



    while true; do


        read -rp \
            "$(echo -e "${CLR_BOLD}Выберите профиль [1-2]${CLR_RESET} [${CLR_YELLOW}1${CLR_RESET}]: ")" \
            answer



        answer="${answer:-1}"



        case "${answer}" in


            1)


                UPS_PROFILE="default"

                break

                ;;


            2)


                UPS_PROFILE="later"

                break

                ;;


            *)


                echo -e \
                    "${CLR_RED}Введите 1 или 2.${CLR_RESET}"

                ;;


        esac


    done



    echo

    echo -e \
        "${CLR_GREEN}✓ Мониторинг ИБП включен (${UPS_PROFILE}).${CLR_RESET}"


}
