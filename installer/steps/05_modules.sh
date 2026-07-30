#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Step 05: Module Installation
# Path: installer/steps/05_modules.sh
# ==============================================================================

set -Eeuo pipefail


readonly MODULES_STEP_COMPONENT="MODULES"



step_modules()
{

    log_info "${MODULES_STEP_COMPONENT}" \
        "Подготовка установки модулей."



    #
    # Проверка выбора модулей
    #

    if [[ -z "${SELECTED_MODULES+x}" ]]; then


        log_error "${MODULES_STEP_COMPONENT}" \
            "Список SELECTED_MODULES не определен."


        return 1

    fi



    if [[ ${#SELECTED_MODULES[@]} -eq 0 ]]; then


        log_warn "${MODULES_STEP_COMPONENT}" \
            "Модули для установки не выбраны."


        return 0

    fi



    log_info "${MODULES_STEP_COMPONENT}" \
        "Выбранные модули:"


    printf ' - %s\n' \
        "${SELECTED_MODULES[@]}"



    #
    # Проверка обязательного API
    #

    local required_functions=(
        module_loader_init
        module_validate_all
        modules_install
        registry_exists
        registry_resolve_order
    )


    local func



    for func in "${required_functions[@]}"
    do

        if ! declare -f "${func}" >/dev/null 2>&1; then


            log_error "${MODULES_STEP_COMPONENT}" \
                "Отсутствует API установки модулей: ${func}"


            return 1

        fi

    done



    #
    # Инициализация загрузчика
    #

    if ! module_loader_init; then


        log_error "${MODULES_STEP_COMPONENT}" \
            "Ошибка инициализации загрузчика модулей."


        return 1

    fi



    #
    # Проверка существования модулей
    #

    local module



    for module in "${SELECTED_MODULES[@]}"
    do


        if ! registry_exists "${module}"; then


            log_error "${MODULES_STEP_COMPONENT}" \
                "Модуль отсутствует в registry: ${module}"


            return 1

        fi


    done



    #
    # Расчет порядка установки
    #

    local install_order=()



    while read -r module
    do

        [[ -z "${module}" ]] && continue

        install_order+=("${module}")


    done < <(
        registry_resolve_order \
            "${SELECTED_MODULES[@]}"
    )



    if [[ ${#install_order[@]} -eq 0 ]]; then


        log_error "${MODULES_STEP_COMPONENT}" \
            "Не удалось определить порядок установки модулей."


        return 1

    fi



    log_info "${MODULES_STEP_COMPONENT}" \
        "Порядок установки:"


    printf ' -> %s\n' \
        "${install_order[@]}"



    #
    # Проверка и установка
    #

    for module in "${install_order[@]}"
    do


        log_info "${MODULES_STEP_COMPONENT}" \
            "Проверка модуля: ${module}"



        if ! module_validate_all "${module}"; then


            log_error "${MODULES_STEP_COMPONENT}" \
                "Модуль не прошел проверку: ${module}"


            return 1

        fi



        log_info "${MODULES_STEP_COMPONENT}" \
            "Установка модуля: ${module}"



        if ! modules_install "${module}"; then


            log_error "${MODULES_STEP_COMPONENT}" \
                "Ошибка установки модуля: ${module}"


            return 1

        fi



        log_success "${MODULES_STEP_COMPONENT}" \
            "Модуль установлен: ${module}"


    done



    log_success "${MODULES_STEP_COMPONENT}" \
        "Все выбранные модули успешно установлены."


    return 0

}



#
# Автономный запуск
#

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then


    LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

    export LSM_ROOT



    source "${LSM_ROOT}/lib/core/common.sh"
    source "${LSM_ROOT}/lib/core/logging.sh"



    source "${LSM_ROOT}/lib/installer/registry.sh"
    source "${LSM_ROOT}/lib/installer/module_loader.sh"
    source "${LSM_ROOT}/lib/installer/module_validator.sh"
    source "${LSM_ROOT}/lib/installer/modules.sh"



    registry_load_default



    SELECTED_MODULES=("$@")



    step_modules


fi
