#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Disk Monitoring Module Installer
# -----------------------------------------------------------------------------

set -Eeuo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LSM_ROOT="${LSM_ROOT:-/opt/lsm}"

# Безопасный поиск и подгрузка библиотек ядра
if [[ -f "${LSM_ROOT}/lib/core/common.sh" ]]; then
    source "${LSM_ROOT}/lib/core/common.sh"
elif [[ -f "${MODULE_DIR}/../../lib/core/common.sh" ]]; then
    source "${MODULE_DIR}/../../lib/core/common.sh"
fi

if [[ -f "${LSM_ROOT}/lib/core/ui.sh" ]]; then
    source "${LSM_ROOT}/lib/core/ui.sh"
elif [[ -f "${MODULE_DIR}/../../lib/core/ui.sh" ]]; then
    source "${MODULE_DIR}/../../lib/core/ui.sh"
fi

if [[ -f "${LSM_ROOT}/lib/installer/deploy.sh" ]]; then
    source "${LSM_ROOT}/lib/installer/deploy.sh"
elif [[ -f "${MODULE_DIR}/../../lib/installer/deploy.sh" ]]; then
    source "${MODULE_DIR}/../../lib/installer/deploy.sh"
fi

log_info "Installing Disk monitoring module..."

# 1. Директории
deploy_create_directory "${LSM_ROOT}/modules/disk" "755" "root" "root"
deploy_create_directory "/etc/lsm/modules" "755" "root" "root"

# 2. Исполняемый файл и манифест
if [[ -f "${MODULE_DIR}/files/check_disk.sh" ]]; then
    deploy_install_file \
        "${MODULE_DIR}/files/check_disk.sh" \
        "${LSM_ROOT}/modules/disk/check_disk.sh" \
        "755" "root" "root"
fi

if [[ -f "${MODULE_DIR}/manifest.conf" ]]; then
    deploy_install_file \
        "${MODULE_DIR}/manifest.conf" \
        "${LSM_ROOT}/modules/disk/manifest.conf" \
        "644" "root" "root"
fi

# 3. Systemd юниты
if [[ -f "${MODULE_DIR}/files/lsm-disk.service" ]]; then
    deploy_install_file "${MODULE_DIR}/files/lsm-disk.service" "/etc/systemd/system/lsm-disk.service" "644" "root" "root"
fi
if [[ -f "${MODULE_DIR}/files/lsm-disk.timer" ]]; then
    deploy_install_file "${MODULE_DIR}/files/lsm-disk.timer" "/etc/systemd/system/lsm-disk.timer" "644" "root" "root"
fi

# 4. Конфигурация
if [[ -f "${MODULE_DIR}/templates/disk.conf" ]]; then
    if [[ ! -f "/etc/lsm/modules/disk.conf" ]]; then
        deploy_install_file "${MODULE_DIR}/templates/disk.conf" "/etc/lsm/modules/disk.conf" "640" "root" "root"
    else
        log_warn "Configuration /etc/lsm/modules/disk.conf already exists, skipping overwrite."
    fi
fi

# 5. Активация таймера
if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload || true
    systemctl enable --now lsm-disk.timer || true
fi

log_success "Disk monitoring module installed successfully."
