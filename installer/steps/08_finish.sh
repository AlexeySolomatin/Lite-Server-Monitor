#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Installation Step 08 - Finish
# -----------------------------------------------------------------------------

set -Eeuo pipefail

# Определение корня и подгрузка библиотек ядра
LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export LSM_ROOT

if [[ -f "${LSM_ROOT}/lib/core/common.sh" ]]; then source "${LSM_ROOT}/lib/core/common.sh"; fi
if [[ -f "${LSM_ROOT}/lib/core/ui.sh" ]]; then source "${LSM_ROOT}/lib/core/ui.sh"; fi

step_finish() {
    print_section "Installation Summary"

    log_success "Lite Server Monitor (v${PROJECT_VERSION}) has been successfully installed!"
    log_info "Config path:  /etc/lsm"
    log_info "Logs path:    /var/log/lsm"
    log_info "CLI command:  lsm status"

    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    step_finish
fi
