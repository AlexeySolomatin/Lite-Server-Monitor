#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Step 03: Directory Structure and Codebase Deployment
# -----------------------------------------------------------------------------

set -Eeuo pipefail

step_directories() {
    log_info "Creating LSM directory structure and deploying files..."

    local target_dir="/opt/lsm"
    local src_dir

    src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

    # Создаем базовые каталоги
    mkdir -p "${target_dir}"/{bin,commands,installer,lib,modules,templates}
    mkdir -p /etc/lsm/modules
    mkdir -p /var/log/lsm

    # Копируем все компоненты проекта, включая installer/
    if [[ "${src_dir}" != "${target_dir}" ]]; then
        cp -rf "${src_dir}/bin" "${target_dir}/"
        cp -rf "${src_dir}/commands" "${target_dir}/"
        cp -rf "${src_dir}/installer" "${target_dir}/"
        cp -rf "${src_dir}/lib" "${target_dir}/"
        cp -rf "${src_dir}/modules" "${target_dir}/"
        cp -rf "${src_dir}/templates" "${target_dir}/" 2>/dev/null || true
    fi

    chmod -R 755 "${target_dir}"
    chmod +x "${target_dir}/bin/lsm" 2>/dev/null || true
    chmod +x "${target_dir}/installer"/*.sh 2>/dev/null || true

    log_success "Directory structure created at ${target_dir}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    LSM_ROOT="${LSM_ROOT:-/opt/lsm}"
    export LSM_ROOT
    if [[ -f "${LSM_ROOT}/lib/core/common.sh" ]]; then source "${LSM_ROOT}/lib/core/common.sh"; fi
    if [[ -f "${LSM_ROOT}/lib/core/ui.sh" ]]; then source "${LSM_ROOT}/lib/core/ui.sh"; fi
    step_directories
fi
