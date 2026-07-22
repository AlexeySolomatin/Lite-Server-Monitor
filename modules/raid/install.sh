#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# RAID Module Installer
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

log_info "Installing RAID monitoring module..."

# 1. Создание целевых каталогов
deploy_create_directory "${LSM_ROOT}/modules/raid" "755" "root" "root"
deploy_create_directory "/etc/lsm/modules" "755" "root" "root"

# 2. Установка скрипта проверки RAID
if [[ -f "${MODULE_DIR}/files/check_raid.sh" ]]; then
    deploy_install_file \
        "${MODULE_DIR}/files/check_raid.sh" \
        "${LSM_ROOT}/modules/raid/check_raid.sh" \
        "755" "root" "root"
else
    log_warn "RAID check script missing: ${MODULE_DIR}/files/check_raid.sh"
fi

# 3. Установка Systemd юнитов и таймера
if [[ -f "${MODULE_DIR}/files/lsm-raid.service" ]]; then
    deploy_install_file \
        "${MODULE_DIR}/files/lsm-raid.service" \
        "/etc/systemd/system/lsm-raid.service" \
        "644" "root" "root"
fi

if [[ -f "${MODULE_DIR}/files/lsm-raid.timer" ]]; then
    deploy_install_file \
        "${MODULE_DIR}/files/lsm-raid.timer" \
        "/etc/systemd/system/lsm-raid.timer" \
        "644" "root" "root"
fi

# 4. Развертывание конфигурации модуля
if [[ -f "${MODULE_DIR}/templates/raid.conf" ]]; then
    if [[ ! -f "/etc/lsm/modules/raid.conf" ]]; then
        deploy_install_file \
            "${MODULE_DIR}/templates/raid.conf" \
            "/etc/lsm/modules/raid.conf" \
            "640" "root" "root"
    else
        log_warn "Configuration /etc/lsm/modules/raid.conf already exists, skipping overwrite."
    fi
fi

# 5. Регистрация и запуск в systemd
if command -v systemctl >/dev/null 2>&1; then
    log_info "Reloading systemd daemon and enabling lsm-raid.timer..."
    systemctl daemon-reload || true
    systemctl enable --now lsm-raid.timer || true
fi

log_success "RAID monitoring module installed successfully."
