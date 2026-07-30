#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Step 07: Permissions Fix
# Path: installer/steps/07_permissions.sh
# -----------------------------------------------------------------------------

set -Eeuo pipefail


readonly PERMISSIONS_STEP_COMPONENT="PERMISSIONS"



step_permissions()
{


    log_info "${PERMISSIONS_STEP_COMPONENT}" \
        "Применение системных прав доступа LSM."



    #
    # Подгрузка библиотеки permissions.sh
    #

    if [[ -f "${LSM_ROOT:-}/lib/installer/permissions.sh" ]]; then

        source "${LSM_ROOT}/lib/installer/permissions.sh"

    fi



    #
    # Проверка API permissions.sh
    #

    if ! declare -f permissions_fix_all >/dev/null 2>&1; then


        log_error "${PERMISSIONS_STEP_COMPONENT}" \
            "Библиотека permissions.sh не загружена."


        return 1

    fi



    #
    # Основные системные права
    #

    if permissions_fix_all; then


        log_success "${PERMISSIONS_STEP_COMPONENT}" \
            "Права доступа LSM успешно применены."


    else


        log_error "${PERMISSIONS_STEP_COMPONENT}" \
            "Ошибка применения прав доступа."


        return 1


    fi



    #
    # Исполняемые файлы
    #

    local lsm_root="${LSM_ROOT:-/opt/lsm}"



    if [[ -d "${lsm_root}" ]]; then


        log_info "${PERMISSIONS_STEP_COMPONENT}" \
            "Проверка исполняемых файлов."



        chmod +x \
            "${lsm_root}/bin/lsm" \
            2>/dev/null || true



        if [[ -d "${lsm_root}/modules" ]]; then


            find "${lsm_root}/modules" \
                -type f \
                -name "*.sh" \
                -exec chmod +x {} \; \
                2>/dev/null || true


        fi

    fi



    log_success "${PERMISSIONS_STEP_COMPONENT}" \
        "Настройка прав завершена."


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


    source "${LSM_ROOT}/lib/installer/permissions.sh"



    step_permissions


fi
