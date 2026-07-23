#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Шаг инсталлятора 05: Установка модулей мониторинга
# Путь: installer/steps/05_modules.sh
# ==============================================================================

set -Eeuo pipefail


step_modules() {


    log_info "Установка выбранных модулей мониторинга..."


    local modules_dir="${LSM_ROOT}/modules"



    #
    # Проверка выбранных модулей
    #
    if [[ ${#SELECTED_MODULES[@]:-0} -eq 0 ]]; then

        log_warn "Список модулей пуст."

        return 0

    fi



    log_info "Выбранные модули: ${SELECTED_MODULES[*]}"



    for module in "${SELECTED_MODULES[@]}"; do


        local module_path="${modules_dir}/${module}"
        local installer="${module_path}/install.sh"



        #
        # Проверка существования модуля
        #
        if [[ ! -d "${module_path}" ]]; then

            log_warn "Модуль '${module}' отсутствует, пропуск."

            continue

        fi



        #
        # Проверка установщика
        #
        if [[ ! -f "${installer}" ]]; then

            log_warn "Установщик модуля '${module}' не найден."

            continue

        fi



        log_info "Установка модуля: ${module}"



        bash "${installer}"



        log_success "Модуль '${module}' установлен."



    done



    log_success "Установка выбранных модулей завершена."

}



#
# Автономный запуск для тестирования
#
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then


    LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

    export LSM_ROOT



    source "${LSM_ROOT}/lib/core/common.sh"

    source "${LSM_ROOT}/lib/core/logging.sh"

    source "${LSM_ROOT}/lib/installer/registry.sh"



    registry_load_default



    SELECTED_MODULES=()


    while read -r module; do

        if [[ "$(registry_default "${module}")" == "yes" ]]; then

            SELECTED_MODULES+=("${module}")

        fi


    done < <(registry_list)



    step_modules

fi
