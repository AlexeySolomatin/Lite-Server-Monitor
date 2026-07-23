#!/usr/bin/env bash
#
# ==============================================================================
# Lite Server Monitor (LSM)
# Экран выбора модулей
# Путь: installer/screens/modules.sh
# ==============================================================================


set -Eeuo pipefail


SELECTED_MODULES=()


screen_modules()
{

    wizard_header


    echo -e "${CLR_BOLD}Выбор модулей мониторинга:${CLR_RESET}"
    echo


    SELECTED_MODULES=()


    if ! declare -f registry_list >/dev/null 2>&1; then

        echo "Ошибка: реестр модулей недоступен."
        return 1

    fi


    while read -r module
    do

        [[ -z "${module}" ]] && continue


        local title="${module}"


        local manifest="${LSM_ROOT}/modules/${module}/manifest.conf"


        if [[ -f "${manifest}" ]]; then

            # shellcheck source=/dev/null
            source "${manifest}"

            title="${MODULE_TITLE:-${module}}"

        fi


        if wizard_yes_no \
            "Установить модуль '${title}'?" \
            "y"
        then

            SELECTED_MODULES+=("${module}")

        fi


    done < <(registry_list)



    if [[ ${#SELECTED_MODULES[@]} -eq 0 ]]; then


        echo
        echo -e "${CLR_YELLOW}Не выбраны модули.${CLR_RESET}"


        if registry_exists "system"; then

            SELECTED_MODULES+=("system")

            echo "Добавлен базовый модуль system."

        fi


        wizard_pause

    fi


}
