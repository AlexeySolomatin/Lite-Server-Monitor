#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Step 05: Module Installation
# Path: installer/steps/05_modules.sh
# ==============================================================================

set -Eeuo pipefail

step_modules()
{

    log_info \
        "Подготовка установки модулей..."

    #
    # Проверка выбора пользователя
    #

    if [[ -z "${SELECTED_MODULES+x}" ]]; then

        log_error \
            "Список модулей SELECTED_MODULES не определен."

        return 1

    fi

    if [[ ${#SELECTED_MODULES[@]} -eq 0 ]]; then

        log_warn \
            "Модули для установки не выбраны."

        return 0

    fi

    log_info \
        "Выбранные модули:"

    printf ' - %s\n' \
        "${SELECTED_MODULES[@]}"

    #
    # Проверка API
    #

    local required_functions=(
        "module_loader_init"
        "module_validate_all"
        "modules_install"
        "registry_exists"
        "registry_resolve_order"
    )

    local func

    for func in "${required_functions[@]}"
    do

        if ! declare -f "${func}" >/dev/null 2>&1; then

            log_error \
                "Отсутствует API установки модулей: ${func}"

            return 1

        fi

    done

    #
    # Инициализация загрузчика
    #

    if ! module_loader_init; then

        log_error \
            "Не удалось инициализировать загрузчик модулей."

        return 1

    fi

    #
    # Проверка существования выбранных модулей
    #

    local module

    for module in "${SELECTED_MODULES[@]}"
    do

        if ! registry_exists "${module}"; then

            log_error \
                "Модуль отсутствует в реестре: ${module}"

            return 1

        fi

    done

    #
    # Разрешение зависимостей
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

        log_error \
            "Не удалось сформировать порядок установки модулей."

        return 1

    fi

    log_info \
        "Порядок установки:"

    printf ' -> %s\n' \
        "${install_order[@]}"

    #
    # Проверка и установка
    #

    for module in "${install_order[@]}"
    do

        log_info \
            "Проверка модуля: ${module}"

        if ! module_validate_all "${module}"; then

            log_error \
                "Модуль не прошел проверку: ${module}"

            return 1

        fi

        log_info \
            "Установка модуля: ${module}"

        if ! modules_install "${module}"; then

            log_error \
                "Ошибка установки модуля: ${module}"

            return 1

        fi

        log_success \
            "Модуль установлен: ${module}"

    done

    log_success \
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

    source "${LSM_ROOT}/lib/installer/module_loader.sh"
    source "${LSM_ROOT}/lib/installer/module_validator.sh"
    source "${LSM_ROOT}/lib/installer/modules.sh"
    source "${LSM_ROOT}/lib/installer/registry.sh"

    registry_load_default

    SELECTED_MODULES=("$@")

    step_modules

fi
