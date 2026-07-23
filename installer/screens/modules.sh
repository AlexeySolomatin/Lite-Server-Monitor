#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Экран выбора модулей установки
# Путь: installer/screens/modules.sh
# ==============================================================================


set -Eeuo pipefail



#
# Выбор модулей
#

screen_modules()
{

    wizard_header


    echo -e "${CLR_BOLD}Выбор модулей мониторинга:${CLR_RESET}"

    echo "Выберите компоненты, которые необходимо установить."
    echo



    SELECTED_MODULES=()



    #
    # Проверка registry
    #

    if ! declare -f registry_list >/dev/null 2>&1; then

        echo -e "${CLR_RED}Ошибка: registry модулей недоступен.${CLR_RESET}"

        return 1

    fi



    #
    # Получение списка модулей
    #

    local modules=()


    while read -r module
    do

        [[ -z "${module}" ]] && continue


        #
        # core не показываем пользователю
        #

        if [[ "${module}" == "core" ]]; then
            continue
        fi


        modules+=("${module}")


    done < <(registry_list)



    #
    # Отображение выбора
    #

    for module in "${modules[@]}"
    do


        local title
        local description
        local default


        title="${LSM_MODULE_TITLE[$module]:-${module}}"

        description="${LSM_MODULE_DESCRIPTION[$module]:-}"

        default="${LSM_MODULE_DEFAULT[$module]:-no}"



        local answer="n"


        if [[ "${default}" == "yes" ]]; then

            answer="y"

        fi



        if wizard_yes_no \
            "${title}: ${description}" \
            "${answer}"; then


            SELECTED_MODULES+=("${module}")


        fi


    done



    #
    # Минимальная проверка
    #

    if [[ ${#SELECTED_MODULES[@]} -eq 0 ]]; then


        echo

        echo -e \
        "${CLR_YELLOW}Не выбран ни один модуль.${CLR_RESET}"


        if wizard_yes_no \
            "Добавить базовый системный мониторинг?" \
            "y"; then


            SELECTED_MODULES+=("system")


        fi


    fi



    #
    # Вывод результата
    #

    echo

    echo -e "${CLR_BOLD}Выбраны модули:${CLR_RESET}"


    if [[ ${#SELECTED_MODULES[@]} -gt 0 ]]; then


        printf " - %s\n" "${SELECTED_MODULES[@]}"


    else


        echo "нет"


    fi


    wizard_pause

}
