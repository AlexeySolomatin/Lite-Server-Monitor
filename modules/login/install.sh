#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Login Module Installer
# -----------------------------------------------------------------------------

set -Eeuo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LSM_ROOT="${LSM_ROOT:-/opt/lsm}"

# Безопасный поиск и подгрузка библиотек ядра!
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

log_info "Installing Login monitoring module..."

# 1. Директории
deploy_create_directory "${LSM_ROOT}/modules/login" "755" "root" "root"
deploy_create_directory "/etc/lsm/modules" "755" "root" "root"

# 2. Исполняемый файл
if [[ -f "${MODULE_DIR}/files/check_login.sh" ]]; then
    deploy_install_file \
        "${MODULE_DIR}/files/check_login.sh" \
        "${LSM_ROOT}/modules/login/check_login.sh" \
        "755" "root" "root"
fi

# 3. Systemd юниты
if [[ -f "${MODULE_DIR}/files/lsm-login.service" ]]; then
    deploy_install_file "${MODULE_DIR}/files/lsm-login.service" "/etc/systemd/system/lsm-login.service" "644" "root" "root"
fi
if [[ -f "${MODULE_DIR}/files/lsm-login.timer" ]]; then
    deploy_install_file "${MODULE_DIR}/files/lsm-login.timer" "/etc/systemd/system/lsm-login.timer" "644" "root" "root"
fi

# 4. Конфигурация
if [[ -f "${MODULE_DIR}/templates/login.conf" ]]; then
    if [[ ! -f "/etc/lsm/modules/login.conf" ]]; then
        deploy_install_file "${MODULE_DIR}/templates/login.conf" "/etc/lsm/modules/login.conf" "640" "root" "root"
    else
        log_warn "Configuration /etc/lsm/modules/login.conf already exists, skipping overwrite."
    fi
fi

# 5. Активация таймера
if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload || true
    systemctl enable --now lsm-login.timer || true
fi

log_success "Login monitoring module installed successfully."
