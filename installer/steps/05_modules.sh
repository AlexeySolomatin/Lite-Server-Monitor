#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Шаг 05: Установка модулей
# Путь: installer/steps/05_modules.sh
# ==============================================================================


set -Eeuo pipefail


step_modules()
{


    log_info "Установка выбранных модулей..."



    if ! declare -p SELECTED_MODULES >/dev/null 2>&1; then


        log_error "Список модулей не определен."

        return 1

    fi



    for module in "${SELECTED_MODULES[@]}"
    do


        if modules_exists "${module}"; then


            modules_install "${module}"


        else


            log_warn \
            "Модуль ${module} отсутствует, пропуск."


        fi


    done



    log_success "Установка модулей завершена."


}
