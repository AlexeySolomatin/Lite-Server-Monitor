#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Step 03: Directory Structure and Codebase Deployment
# -----------------------------------------------------------------------------

set -Eeuo pipefail

step_directories() {
    log_info "Creating LSM directory structure and deploying files..."

    local target="${LSM_ROOT:-/opt/lsm}"
    local src_dir

    src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

    mkdir -p "${target}"/{bin,commands,installer,lib,modules,templates}
    mkdir -p /etc/lsm/modules
    mkdir -p /var/log/lsm

    # Копирование исходных файлов в целевую систему
    if [[ "${src_dir}" != "${target}" ]]; then
        cp -rf "${src_dir}/bin" "${target}/"
        cp -rf "${src_dir}/commands" "${target}/"
        cp -rf "${src_dir}/lib" "${target}/"
        cp -rf "${src_dir}/modules" "${target}/"
        cp -rf "${src_dir}/templates" "${target}/" 2>/dev/null || true
    fi

    chmod -R 755 "${target}"
    chmod +x "${target}/bin/lsm"

    log_success "Directory structure created at ${target}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    LSM_ROOT="${LSM_ROOT:-/opt/lsm}"
    export LSM_ROOT
    if [[ -f "${LSM_ROOT}/lib/core/common.sh" ]]; then source "${LSM_ROOT}/lib/core/common.sh"; fi
    if [[ -f "${LSM_ROOT}/lib/core/ui.sh" ]]; then source "${LSM_ROOT}/lib/core/ui.sh"; fi
    step_directories
fi
