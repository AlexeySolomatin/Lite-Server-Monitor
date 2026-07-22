#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Step 07: Global CLI Symlink
# -----------------------------------------------------------------------------

set -Eeuo pipefail

step_cli() {
    log_info "Creating global CLI symlink (/usr/local/bin/lsm)..."

    local target_bin="${LSM_ROOT:-/opt/lsm}/bin/lsm"
    local symlink_path="/usr/local/bin/lsm"

    if [[ -f "${target_bin}" ]]; then
        chmod +x "${target_bin}"
        ln -sf "${target_bin}" "${symlink_path}"
        log_success "Symlink created: ${symlink_path} -> ${target_bin}"
    else
        log_error "Executable not found at ${target_bin}"
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
    export LSM_ROOT
    if [[ -f "${LSM_ROOT}/lib/core/common.sh" ]]; then source "${LSM_ROOT}/lib/core/common.sh"; fi
    if [[ -f "${LSM_ROOT}/lib/core/ui.sh" ]]; then source "${LSM_ROOT}/lib/core/ui.sh"; fi
    step_cli
fi
