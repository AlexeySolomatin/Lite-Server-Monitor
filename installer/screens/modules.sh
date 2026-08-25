#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Экран выбора модулей установки
#
# Путь:
#   installer/screens/modules.sh
#
# Назначение:
#   Используется только в режиме "Настраиваемая установка".
#
#   Пользователь выбирает модули мониторинга в интерактивном
#   чек-листе (Advanced CLI):
#
#       цифра  - переключение пункта [ ] <-> [X];
#       0      - подтверждение выбора.
#
#   Системный модуль core устанавливается автоматически
#   и в списке не отображается.
#
# Зависимости:
#   installer/screens/common.sh (wizard_checklist)
#   lib/installer/registry.sh
# ==============================================================================

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
        "Отметьте компоненты, которые необходимо установить."


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
    # Получение списка модулей.
    #
    # Системный модуль core устанавливается автоматически,
    # поэтому в чек-лист не включается.
    #

    local modules=()


    local module


    while read -r module; do


        [[ -z "${module}" ]] && continue



        if [[ "${module}" == "core" ]]; then

            continue

        fi



        modules+=("${module}")


    done < <(registry_list)



    if (( ${#modules[@]} == 0 )); then


        echo -e \
            "${CLR_RED}Ошибка: доступные модули не найдены.${CLR_RESET}"


        return 1


    fi



    #
    # Подготовка элементов чек-листа и предвыборки.
    #
    # Предварительно отмечаются модули с MODULE_DEFAULT="yes".
    #

    local items=()

    local defaults_str=""


    local i=0


    for module in "${modules[@]}"; do


        local title
        local description


        title="${LSM_MODULE_NAME[$module]:-${module}}"


        description="${LSM_MODULE_DESCRIPTION[$module]:-Нет описания}"


        items+=("${title} — ${description}")



        if [[ "${LSM_MODULE_DEFAULT[$module]:-no}" == "yes" ]]; then

            defaults_str+="${i} "

        fi


        i=$((i + 1))


    done


    defaults_str="${defaults_str% }"



    echo -e \
        "${CLR_CYAN}Системный модуль core будет установлен автоматически.${CLR_RESET}"

    echo



    #
    # Интерактивный чек-лист.
    #
    # Результат: массив WIZARD_MODULE_SELECTION (индексы элементов).
    #

    local WIZARD_MODULE_SELECTION=()


    wizard_checklist \
        "Выбор модулей мониторинга" \
        WIZARD_MODULE_SELECTION \
        "${defaults_str}" \
        "ЗАВЕРШИТЬ ВЫБОР МОДУЛЕЙ" \
        "${items[@]}"



    #
    # Преобразование индексов в идентификаторы модулей
    #

    local sel_idx


    for sel_idx in ${WIZARD_MODULE_SELECTION[@]+"${WIZARD_MODULE_SELECTION[@]}"}; do


        SELECTED_MODULES+=("${modules[${sel_idx}]}")


    done



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
