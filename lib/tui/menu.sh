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

while true
do


CHOICE=$(dialog \
--clear \
--title "Lite Server Monitor" \
--menu "Главное меню" \
20 70 10 \
1 "Установка компонентов" \
2 "Управление модулями" \
3 "Конфигурация" \
4 "Отчеты" \
5 "Диагностика системы" \
6 "Информация о системе" \
0 "Выход" \
3>&1 1>&2 2>&3)



case "${CHOICE}" in


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

break

;;


esac


done

}
