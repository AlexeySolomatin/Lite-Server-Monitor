#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Экран выбора модулей установки
# Путь: installer/screens/modules.sh
#
# Назначение:
#   Используется только в режиме "Настраиваемая установка".
#
#   Пользователь выбирает, какие модули мониторинга установить.
# -----------------------------------------------------------------------------

set -Eeuo pipefail



#
# Выбор модулей
#

screen_modules()
{


    wizard_header



    echo -e \
        "${CLR_BOLD}Выбор модулей мониторинга:${CLR_RESET}"


    echo \
        "Выберите компоненты, которые необходимо установить."


    echo



    SELECTED_MODULES=()



    #
    # Проверка доступности registry
    #

    if ! declare -f registry_list >/dev/null 2>&1; then


        echo -e \
            "${CLR_RED}Ошибка: реестр модулей недоступен.${CLR_RESET}"


        return 1


    fi



    #
    # Получение списка модулей
    #

    local modules=()


    local module



    while read -r module; do


        [[ -z "${module}" ]] && continue



        #
        # Системный модуль core устанавливается автоматически
        #

        if [[ "${module}" == "core" ]]; then

            continue

        fi



        modules+=("${module}")


    done < <(registry_list)



    #
    # Выбор каждого модуля
    #

    for module in "${modules[@]}"; do



        local title
        local description



        title="${LSM_MODULE_NAME[$module]:-${module}}"


        description="${LSM_MODULE_DESCRIPTION[$module]:-Нет описания}"



        if wizard_yes_no \
            "${title}: ${description}" \
            "y"; then


            SELECTED_MODULES+=("${module}")


        fi


    done



    #
    # Если ничего не выбрано
    #

    if [[ ${#SELECTED_MODULES[@]} -eq 0 ]]; then


        echo


        echo -e \
            "${CLR_YELLOW}Не выбран ни один модуль.${CLR_RESET}"



        if wizard_yes_no \
            "Добавить системный мониторинг?" \
            "y"; then


            SELECTED_MODULES=("system")


        fi


    fi



    #
    # Итог выбора
    #

    echo


    echo -e \
        "${CLR_BOLD}Выбранные модули:${CLR_RESET}"



    if [[ ${#SELECTED_MODULES[@]} -gt 0 ]]; then


        printf " - %s\n" "${SELECTED_MODULES[@]}"


    else


        echo "нет"


    fi



    wizard_pause


}
