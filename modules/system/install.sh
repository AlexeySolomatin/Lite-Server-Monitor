#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Инсталлятор модуля мониторинга системных ресурсов
# -----------------------------------------------------------------------------

set -Eeuo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LSM_ROOT="${LSM_ROOT:-/opt/lsm}"

if [[ -f "${LSM_ROOT}/lib/core/common.sh" ]]; then source "${LSM_ROOT}/lib/core/common.sh"; fi
if [[ -f "${LSM_ROOT}/lib/core/ui.sh" ]]; then source "${LSM_ROOT}/lib/core/ui.sh"; fi
if [[ -f "${LSM_ROOT}/lib/installer/deploy.sh" ]]; then source "${LSM_ROOT}/lib/installer/deploy.sh"; fi

log_info "SYSTEM" "Установка модуля мониторинга системных ресурсов..."

# 1. Директории
deploy_create_directory "/etc/lsm/modules" "755" "root" "root"

# 2. Systemd юниты
#    Исполняемый файл уже развернут в /opt/lsm/modules/system/files/check_system.sh
if [[ -f "${MODULE_DIR}/files/lsm-system.service" ]]; then
    deploy_install_file "${MODULE_DIR}/files/lsm-system.service" "/etc/systemd/system/lsm-system.service" "644" "root" "root"
fi
if [[ -f "${MODULE_DIR}/files/lsm-system.timer" ]]; then
    deploy_install_file "${MODULE_DIR}/files/lsm-system.timer" "/etc/systemd/system/lsm-system.timer" "644" "root" "root"
fi

# 3. Конфигурация (без перезаписи существующей)
if [[ -f "${MODULE_DIR}/templates/system.conf" ]]; then
    if [[ ! -f "/etc/lsm/modules/system.conf" ]]; then
        deploy_install_file "${MODULE_DIR}/templates/system.conf" "/etc/lsm/modules/system.conf" "640" "root" "root"
    else
        log_warn "SYSTEM" "Конфигурация /etc/lsm/modules/system.conf уже существует, пропуск перезаписи."
    fi
fi

# 4. Активация таймера
if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload || true
    systemctl enable --now lsm-system.timer || true
fi

log_success "SYSTEM" "Модуль мониторинга системных ресурсов успешно установлен."
