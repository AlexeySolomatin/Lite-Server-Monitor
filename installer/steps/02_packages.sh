#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Step 02: Package Dependencies Installation
# -----------------------------------------------------------------------------

set -Eeuo pipefail

step_packages() {
    log_info "Installing required packages..."

    log_info "Updating package index..."
    if ! apt-get update -y; then
        log_warn "APT update failed. Cleaning lists and retrying..."
        rm -rf /var/lib/apt/lists/*
        apt-get update -y || log_warn "APT update finished with warnings, proceeding..."
    fi

    local pkgs=(curl wget jq bc msmtp smartmontools mdadm lm-sensors fail2ban)

    for pkg in "${pkgs[@]}"; do
        if dpkg -s "$pkg" &>/dev/null; then
            log_info "Package already installed: $pkg"
        else
            log_info "Installing package: $pkg..."
            DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
        fi
    done

    log_success "All required packages are installed."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    LSM_ROOT="${LSM_ROOT:-/opt/lsm}"
    export LSM_ROOT
    if [[ -f "${LSM_ROOT}/lib/core/common.sh" ]]; then source "${LSM_ROOT}/lib/core/common.sh"; fi
    if [[ -f "${LSM_ROOT}/lib/core/ui.sh" ]]; then source "${LSM_ROOT}/lib/core/ui.sh"; fi
    step_packages
fi
