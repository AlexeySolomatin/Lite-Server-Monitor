#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Этап 07: Настройка прав доступа
#
# Путь:
#   installer/steps/07_permissions.sh
#
# Назначение:
#   Настройка прав доступа к файлам и каталогам LSM.
#
# ==============================================================================
set -Eeuo pipefail

readonly PERMISSIONS_STEP_COMPONENT="PERMISSIONS"


#
# Настройка прав доступа
#

step_permissions()
{
    log_info "${PERMISSIONS_STEP_COMPONENT}" \
        "Применение системных прав доступа LSM."


    #
    # Подключение библиотеки настройки прав
    #

    if [[ -f "${LSM_ROOT:-}/lib/installer/permissions.sh" ]]; then

        # shellcheck source=/dev/null
        source "${LSM_ROOT}/lib/installer/permissions.sh"

    fi


    #
    # Проверка API библиотеки permissions.sh
    #

    if ! declare -f permissions_fix_all >/dev/null 2>&1; then

        log_error "${PERMISSIONS_STEP_COMPONENT}" \
            "Библиотека permissions.sh не загружена."

        return 1

    fi


    #
    # Применение основных системных прав
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
    # Настройка исполняемых файлов
    #

    local lsm_root="${LSM_INSTALL_DIR:-/opt/lsm}"

    if [[ -d "${lsm_root}" ]]; then

        log_info "${PERMISSIONS_STEP_COMPONENT}" \
            "Проверка исполняемых файлов."


        #
        # Основной CLI LSM
        #

        if [[ ! -f "${lsm_root}/bin/lsm" ]]; then

            log_error "${PERMISSIONS_STEP_COMPONENT}" \
                "Исполняемый файл LSM не найден: ${lsm_root}/bin/lsm"

            return 1

        fi


        chmod +x \
            "${lsm_root}/bin/lsm" \
            2>/dev/null || true


        #
        # Исполняемые файлы модулей
        #

        if [[ -d "${lsm_root}/modules" ]]; then

            find "${lsm_root}/modules" \
                -type f \
                -name "*.sh" \
                -exec chmod +x {} \; \
                2>/dev/null || true

        fi


        #
        # Системная команда LSM
        #
        # Ссылка создаётся здесь, после развёртывания файлов
        # и настройки их прав.
        #

        if [[ -x "${lsm_root}/bin/lsm" ]]; then

            log_info "${PERMISSIONS_STEP_COMPONENT}" \
                "Создание системной ссылки /usr/local/bin/lsm."

            deploy_create_symlink \
                "${lsm_root}/bin/lsm" \
                "/usr/local/bin/lsm"

        else

            log_error "${PERMISSIONS_STEP_COMPONENT}" \
                "CLI LSM не является исполняемым: ${lsm_root}/bin/lsm"

            return 1

        fi

    else

        log_error "${PERMISSIONS_STEP_COMPONENT}" \
            "Каталог установки LSM не найден: ${lsm_root}"

        return 1

    fi


    #
    # Завершение этапа
    #

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


    #
    # Подключение базовых библиотек
    #

    source "${LSM_ROOT}/lib/core/common.sh"
    source "${LSM_ROOT}/lib/core/logging.sh"
    source "${LSM_ROOT}/lib/installer/deploy.sh"
    source "${LSM_ROOT}/lib/installer/permissions.sh"


    #
    # Запуск этапа
    #

    step_permissions

fi
