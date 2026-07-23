#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Виджет меню TUI
# Путь: lib/tui/widgets/menu.sh
# ==============================================================================


set -Eeuo pipefail


[[ -n "${LSM_TUI_MENU_WIDGET_LOADED:-}" ]] && return 0
readonly LSM_TUI_MENU_WIDGET_LOADED=1



#
# Простое меню выбора
#
# Использование:
#
# tui_menu_create \
#     "Заголовок" \
#     "Описание" \
#     "1" "Пункт 1" \
#     "2" "Пункт 2"
#
# Результат:
#
# TUI_MENU_RESULT
#


tui_menu_create()
{

    local title="$1"
    local text="$2"

    shift 2


    TUI_MENU_RESULT="$(
        dialog \
            --clear \
            --title "${title}" \
            --menu "${text}" \
            20 70 12 \
            "$@" \
            3>&1 1>&2 2>&3
    )"



    export TUI_MENU_RESULT

}



#
# Меню подтверждения
#

tui_confirm()
{

    local message="$1"


    dialog \
        --clear \
        --yesno "${message}" \
        10 50


}



#
# Окно информации
#

tui_message()
{

    local title="$1"
    local text="$2"


    dialog \
        --clear \
        --title "${title}" \
        --msgbox "${text}" \
        12 60

}
