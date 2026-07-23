#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Главное меню TUI
# Путь: lib/tui/menu.sh
# ==============================================================================

set -Eeuo pipefail


[[ -n "${LSM_TUI_MENU_LOADED:-}" ]] && return 0
readonly LSM_TUI_MENU_LOADED=1



tui_main_menu()
{

    tui_menu_create \
        "Lite Server Monitor" \
        "Главное меню" \
        1 "Установка компонентов" \
        2 "Управление модулями" \
        3 "Конфигурация" \
        4 "Отчеты" \
        5 "Диагностика системы" \
        6 "Информация о системе" \
        0 "Выход"



    case "${TUI_MENU_RESULT}" in


        1)
            screen_install
        ;;


        2)
            screen_modules
        ;;


        3)
            screen_config
        ;;


        4)
            screen_report
        ;;


        5)
            screen_doctor
        ;;


        6)
            screen_info
        ;;


        0|*)
            return 1
        ;;


    esac

}
