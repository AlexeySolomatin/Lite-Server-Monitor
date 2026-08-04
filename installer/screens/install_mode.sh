#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Экран выбора режима установки
#
# Путь:
#   installer/screens/install_mode.sh
#
# Назначение:
#   Выбор режима установки системы.
#
# Режимы:
#
#   standard:
#       - установка всех зарегистрированных модулей;
#       - установка стандартных конфигураций;
#       - настройка только уведомлений.
#
#   custom:
#       - выбор модулей;
#       - настройка дополнительных параметров;
#       - ручная настройка ИБП и отчетов.
# ==============================================================================

set -Eeuo pipefail



#
# Режим установки по умолчанию
#

INSTALL_MODE="standard"



#
# Экран выбора режима установки
#

screen_install_mode()
{

    wizard_header


    echo -e "${CLR_BOLD}Выберите режим установки:${CLR_RESET}"
    echo


    echo -e "  ${CLR_CYAN}1)${CLR_RESET} ${CLR_BOLD}Стандартная установка (рекомендуется)${CLR_RESET}"

    echo "     Установка всех доступных модулей LSM."
    echo "     Создание стандартных конфигураций."
    echo "     Настройка только Telegram и Email уведомлений."

    echo



    echo -e "  ${CLR_CYAN}2)${CLR_RESET} ${CLR_BOLD}Настраиваемая установка${CLR_RESET}"

    echo "     Выбор необходимых модулей."
    echo "     Настройка уведомлений."
    echo "     Настройка ИБП и ежедневных отчетов."

    echo



    while true
    do

        read -rp \
            "$(echo -e "${CLR_BOLD}Выберите режим [1-2]${CLR_RESET} [${CLR_YELLOW}1${CLR_RESET}]: ")" \
            answer


        answer="${answer:-1}"



        case "${answer}" in


            1)

                INSTALL_MODE="standard"

                break

                ;;



            2)

                INSTALL_MODE="custom"

                break

                ;;



            *)

                echo -e \
                    "${CLR_RED}Неверный выбор. Введите 1 или 2.${CLR_RESET}"

                ;;


        esac


    done


}
