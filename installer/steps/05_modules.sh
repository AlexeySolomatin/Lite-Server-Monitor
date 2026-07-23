#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Шаг 05: Установка модулей мониторинга
# Путь: installer/steps/05_modules.sh
# ==============================================================================


set -Eeuo pipefail



step_modules()
{

    log_info "Подготовка установки модулей..."



    #
    # Проверка выбранных модулей
    #

    if [[ -z "${SELECTED_MODULES+x}" ]]; then

        log_error "Список выбранных модулей не определен."

        return 1

    fi



    if [[ ${#SELECTED_MODULES[@]} -eq 0 ]]; then

        log_warn "Модули для установки не выбраны."

        return 0

    fi



    log_info "Выбраны модули:"
    printf ' - %s\n' "${SELECTED_MODULES[@]}"



    #
    # Проверка registry
    #

    if ! declare -f registry_resolve_order >/dev/null 2>&1; then

        log_error "Registry модулей не загружен."

        return 1

    fi



    #
    # Формирование порядка установки
    #

    local install_order=()


    while read -r module
    do

        [[ -z "${module}" ]] && continue

        install_order+=("${module}")


    done < <(
        registry_resolve_order "${SELECTED_MODULES[@]}"
    )



    echo

    log_info "Порядок установки модулей:"


    printf ' -> %s\n' "${install_order[@]}"



    #
    # Установка
    #

    for module in "${install_order[@]}"
    do


        log_info "Проверка зависимостей: ${module}"


        if ! registry_check_dependencies "${module}"; then

            log_error \
            "Проверка зависимостей не пройдена для ${module}"

            return 1

        fi



        log_info "Установка модуля: ${module}"



        if ! modules_install "${module}"; then

            log_error \
            "Ошибка установки модуля: ${module}"

            return 1

        fi



        log_success \
        "Модуль ${module} установлен."


    done



    log_success "Все модули успешно установлены."

}



#
# Автономный запуск
#

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then


    LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

    export LSM_ROOT



    source "${LSM_ROOT}/lib/core/common.sh"
    source "${LSM_ROOT}/lib/core/logging.sh"
    source "${LSM_ROOT}/lib/installer/modules.sh"
    source "${LSM_ROOT}/lib/installer/registry.sh"



    registry_load_default



    SELECTED_MODULES=("$@")


    step_modules

fi
