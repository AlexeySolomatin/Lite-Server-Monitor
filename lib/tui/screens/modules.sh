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


        local title

        title=$(module_get_name "${module}" 2>/dev/null || echo "${module}")


        menu_items+=(
            "${module}"
            "${title}"
        )


    done <<< "${modules}"



    selected=$(dialog \
        --clear \
        --title "Модули LSM" \
        --checklist \
        "Выберите модули для установки" \
        20 70 12 \
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



    tui_message \
        "Выбрано" \
        "$(printf '%s\n' "${SELECTED_MODULES[@]}")"

}
