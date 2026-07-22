#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Temperature Module Installer
# -----------------------------------------------------------------------------

set -Eeuo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LSM_ROOT="${LSM_ROOT:-/opt/lsm}"

if [[ -f "${LSM_ROOT}/lib/core/common.sh" ]]; then source "${LSM_ROOT}/lib/core/common.sh"; fi
if [[ -f "${LSM_ROOT}/lib/core/ui.sh" ]]; then source "${LSM_ROOT}/lib/core/ui.sh"; fi
if [[ -f "${LSM_ROOT}/lib/installer/deploy.sh" ]]; then source "${LSM_ROOT}/lib/installer/deploy.sh"; fi

log_info "Installing Temperature monitoring module..."

# 1. Директории
deploy_create_directory "${LSM_ROOT}/modules/temperature" "755" "root" "root"
deploy_create_directory "/etc/lsm/modules" "755" "root" "root"

# 2. Исполняемый файл
if [[ -f "${MODULE_DIR}/files/check_temperature.sh" ]]; then
    deploy_install_file \
        "${MODULE_DIR}/files/check_temperature.sh" \
        "${LSM_ROOT}/modules/temperature/check_temperature.sh" \
        "755" "root" "root"
fi

# 3. Systemd юниты
if [[ -f "${MODULE_DIR}/files/lsm-temperature.service" ]]; then
    deploy_install_file "${MODULE_DIR}/files/lsm-temperature.service" "/etc/systemd/system/lsm-temperature.service" "644" "root" "root"
fi
if [[ -f "${MODULE_DIR}/files/lsm-temperature.timer" ]]; then
    deploy_install_file "${MODULE_DIR}/files/lsm-temperature.timer" "/etc/systemd/system/lsm-temperature.timer" "644" "root" "root"
fi

# 4. Конфигурация
if [[ -f "${MODULE_DIR}/templates/temperature.conf" ]]; then
    if [[ ! -f "/etc/lsm/modules/temperature.conf" ]]; then
        deploy_install_file "${MODULE_DIR}/templates/temperature.conf" "/etc/lsm/modules/temperature.conf" "640" "root" "root"
    else
        log_warn "Configuration /etc/lsm/modules/temperature.conf already exists, skipping overwrite."
    fi
fi

# 5. Активация таймера
if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload || true
    systemctl enable --now lsm-temperature.timer || true
fi

log_success "Temperature monitoring module installed successfully."
