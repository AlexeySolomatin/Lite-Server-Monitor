#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Step 05: Installation of Monitoring Modules
# -----------------------------------------------------------------------------

set -Eeuo pipefail

step_modules() {
    log_info "Installing enabled monitoring modules..."

    local modules=(
        "disk"
        "fail2ban"
        "login"
        "raid"
        "smart"
        "system"
        "temperature"
        "ups"
    )

    for mod in "${modules[@]}"; do
        local mod_installer="${LSM_ROOT:-/opt/lsm}/modules/${mod}/install.sh"
        if [[ -f "${mod_installer}" ]]; then
            log_info "Triggering module installer: ${mod}..."
            bash "${mod_installer}"
        else
            log_warn "Module installer not found: ${mod_installer}"
        fi
    done

    log_success "All monitoring modules installed."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
    export LSM_ROOT
    if [[ -f "${LSM_ROOT}/lib/core/common.sh" ]]; then source "${LSM_ROOT}/lib/core/common.sh"; fi
    if [[ -f "${LSM_ROOT}/lib/core/ui.sh" ]]; then source "${LSM_ROOT}/lib/core/ui.sh"; fi
    step_modules
fi
