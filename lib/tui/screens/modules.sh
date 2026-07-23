#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# TUI Управление модулями
# Путь: lib/tui/screens/modules.sh
# ==============================================================================


set -Eeuo pipefail



screen_modules()
{

while true
do


local items=()

local index=1



while read -r module
do

    items+=(
        "${index}"
        "${module}"
    )

    MODULE_INDEX_${index}="${module}"

    ((index++))


done < <(registry_list)



items+=(
    "0"
    "Назад"
)



CHOICE=$(dialog \
--clear \
--title "Модули LSM" \
--menu "Выберите действие" \
20 60 12 \
"${items[@]}" \
3>&1 1>&2 2>&3)



[[ "${CHOICE}" == "0" ]] && break



MODULE="${MODULE_INDEX_${CHOICE}}"



screen_module_actions "${MODULE}"



done

}



screen_module_actions()
{

local module="$1"



while true
do


ACTION=$(dialog \
--clear \
--title "Модуль: ${module}" \
--menu "Действие" \
15 60 8 \
1 "Информация" \
2 "Установить" \
3 "Удалить" \
4 "Назад" \
3>&1 1>&2 2>&3)



case "${ACTION}" in


1)

module_info "${module}" \
| dialog \
--title "${module}" \
--textbox - \
20 70

;;


2)

modules_install "${module}"

tui_msg \
"Установка" \
"Модуль ${module} установлен"

;;


3)

modules_remove "${module}"

tui_msg \
"Удаление" \
"Модуль ${module} удален"

;;


4|*)

break

;;


esac


done

}
