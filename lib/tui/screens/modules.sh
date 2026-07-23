#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Экран управления модулями TUI
# Путь: lib/tui/screens/modules.sh
# ==============================================================================


set -Eeuo pipefail


[[ -n "${LSM_TUI_MODULES_SCREEN_LOADED:-}" ]] && return 0
readonly LSM_TUI_MODULES_SCREEN_LOADED=1



#
# Просмотр информации о модуле
#

screen_module_info()
{

    local module="$1"


    if ! declare -f module_get_metadata >/dev/null 2>&1; then

        tui_error "API метаданных модулей недоступен."

        return 1

    fi



    local info

    info=$(module_get_metadata "${module}")



    tui_message \
        "Информация о модуле" \
        "${info}"

}



#
# Экран выбора модулей
#

screen_modules()
{

    local modules
    local menu_items=()
    local selected



    if ! declare -f module_loader_list >/dev/null 2>&1; then

        tui_error "API загрузчика модулей недоступен."

        return 1

    fi



    modules=$(module_loader_list)



    if [[ -z "${modules}" ]]; then

        tui_warning "Доступные модули не найдены."

        return 0

    fi



    while read -r module
    do

        [[ -z "${module}" ]] && continue



        local name
        local category



        name=$(module_get_name "${module}" 2>/dev/null || echo "${module}")

        category=$(module_get_category "${module}" 2>/dev/null || echo "unknown")



        menu_items+=(
            "${module}"
            "${name} [${category}]"
        )


    done <<< "${modules}"



    selected=$(dialog \
        --clear \
        --title "Модули LSM" \
        --checklist \
        "Выберите модули для установки или управления" \
        22 80 14 \
        "${menu_items[@]}" \
        3>&1 1>&2 2>&3
    ) || true



    SELECTED_MODULES=()



    for module in ${selected}
    do

        module="${module//\"/}"

        SELECTED_MODULES+=("${module}")

    done



    if [[ ${#SELECTED_MODULES[@]} -eq 0 ]]; then

        tui_warning "Не выбран ни один модуль."

        return 0

    fi



    local result

    result=$(printf '%s\n' "${SELECTED_MODULES[@]}")



    tui_message \
        "Выбранные модули" \
        "${result}"

}
