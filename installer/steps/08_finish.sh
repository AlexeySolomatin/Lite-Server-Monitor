#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Installation Step 08 - Finish
# Path: installer/steps/08_finish.sh
# -----------------------------------------------------------------------------

set -Eeuo pipefail

#
# Environment
#

LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
LSM_INSTALL_DIR="${LSM_INSTALL_DIR:-/opt/lsm}"

export LSM_ROOT
export LSM_INSTALL_DIR

#
# Core libraries
#

source "${LSM_ROOT}/lib/core/common.sh"
source "${LSM_ROOT}/lib/core/logging.sh"
source "${LSM_ROOT}/lib/core/ui.sh"

readonly FINISH_COMPONENT="FINISH"

step_finish()
{
    print_section "Installation Summary"

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
            "CLI executable missing or not executable: ${expected_cli}"
    
        errors=$((errors + 1))
    
    fi
    
    #
    # Проверка системной ссылки CLI
    #
    
    cli_path="$(readlink -f "/usr/local/bin/lsm" 2>/dev/null || true)"
    
    if [[ "${cli_path}" != "${expected_cli}" ]]; then
    
        log_error "${FINISH_COMPONENT}" \
            "CLI command points to an invalid location: ${cli_path}"
    
        log_error "${FINISH_COMPONENT}" \
            "Expected location: ${expected_cli}"
    
        errors=$((errors + 1))
    
    fi

    #
    # Проверка каталога журналов
    #

    if [[ ! -d "/var/log/lsm" ]]; then

        log_warn "${FINISH_COMPONENT}" \
            "Log directory missing."

    fi

    #
    # Итог проверки
    #

    if (( errors > 0 )); then

        log_error "${FINISH_COMPONENT}" \
            "Installation completed with errors: ${errors}"

        return 1

    fi

    #
    # Установка завершена успешно
    #

    log_success "${FINISH_COMPONENT}" \
        "Lite Server Monitor v${PROJECT_VERSION} successfully installed."

    echo

    log_info "${FINISH_COMPONENT}" \
        "Installation path: ${LSM_INSTALL_DIR}"

    log_info "${FINISH_COMPONENT}" \
        "Configuration: /etc/lsm"

    log_info "${FINISH_COMPONENT}" \
        "Logs: /var/log/lsm"

    log_info "${FINISH_COMPONENT}" \
        "CLI: lsm status"

    #
    # Installed modules
    #

    if declare -f modules_installed_list >/dev/null 2>&1; then

        echo

        log_info "${FINISH_COMPONENT}" \
            "Installed modules:"

        while read -r module; do

            [[ -z "${module}" ]] && continue

            echo " - ${module}"

        done < <(modules_installed_list)

    fi

    echo

    log_success "${FINISH_COMPONENT}" \
        "Installation finished."

    return 0
}

#
# Standalone execution
#

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    step_finish
fi
