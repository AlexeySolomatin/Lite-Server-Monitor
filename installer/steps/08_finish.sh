#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Шаг 08: Завершение установки
#
# Путь:
#   installer/steps/08_finish.sh
#
# Назначение:
#   Финальная проверка результатов установки и вывод сводки.
#
# ==============================================================================

set -Eeuo pipefail

#
# Окружение
#

LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
LSM_INSTALL_DIR="${LSM_INSTALL_DIR:-/opt/lsm}"

export LSM_ROOT
export LSM_INSTALL_DIR

#
# Библиотеки ядра
#

source "${LSM_ROOT}/lib/core/common.sh"
source "${LSM_ROOT}/lib/core/logging.sh"
source "${LSM_ROOT}/lib/core/ui.sh"

readonly FINISH_COMPONENT="FINISH"

step_finish()
{
    print_section "Итоги установки"

    #
    # Проверка основных компонентов
    #

    local errors=0
    local cli_path
    local expected_cli="${LSM_INSTALL_DIR}/bin/lsm"
    
    #
    # Проверка исполняемого файла CLI
    #
    
    if [[ ! -x "${expected_cli}" ]]; then
    
        log_error "${FINISH_COMPONENT}" \
            "Исполняемый файл CLI отсутствует или не является исполняемым: ${expected_cli}"
    
        errors=$((errors + 1))
    
    fi
    
    #
    # Проверка системной ссылки CLI
    #
    
    cli_path="$(readlink -f "/usr/local/bin/lsm" 2>/dev/null || true)"
    
    if [[ "${cli_path}" != "${expected_cli}" ]]; then
    
        log_error "${FINISH_COMPONENT}" \
            "Команда lsm указывает на неверное расположение: ${cli_path}"

        log_error "${FINISH_COMPONENT}" \
            "Ожидаемое расположение: ${expected_cli}"
    
        errors=$((errors + 1))
    
    fi

    #
    # Проверка каталога журналов
    #

    if [[ ! -d "/var/log/lsm" ]]; then

        log_warn "${FINISH_COMPONENT}" \
            "Каталог журналов отсутствует."

    fi

    #
    # Итог проверки
    #

    if (( errors > 0 )); then

        log_error "${FINISH_COMPONENT}" \
            "Установка завершена с ошибками: ${errors}"

        return 1

    fi

    #
    # Установка завершена успешно
    #

    log_success "${FINISH_COMPONENT}" \
        "Lite Server Monitor v${PROJECT_VERSION} успешно установлен."

    echo

    log_info "${FINISH_COMPONENT}" \
        "Каталог установки: ${LSM_INSTALL_DIR}"

    log_info "${FINISH_COMPONENT}" \
        "Конфигурация: /etc/lsm"

    log_info "${FINISH_COMPONENT}" \
        "Журналы: /var/log/lsm"

    log_info "${FINISH_COMPONENT}" \
        "CLI: lsm status"

    #
    # Установленные модули
    #

    if declare -f modules_installed_list >/dev/null 2>&1; then

        echo

        log_info "${FINISH_COMPONENT}" \
            "Установленные модули:"

        while read -r module; do

            [[ -z "${module}" ]] && continue

            echo " - ${module}"

        done < <(modules_installed_list)

    fi

    echo

    log_success "${FINISH_COMPONENT}" \
        "Установка завершена."

    return 0
}

#
# Автономный запуск
#

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    step_finish
fi
