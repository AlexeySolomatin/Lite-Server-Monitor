#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Инсталлятор модуля мониторинга SMART
# -----------------------------------------------------------------------------

set -Eeuo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LSM_ROOT="${LSM_ROOT:-/opt/lsm}"

# Загрузка библиотек ядра
if [[ -f "${LSM_ROOT}/lib/core/common.sh" ]]; then source "${LSM_ROOT}/lib/core/common.sh"; fi
if [[ -f "${LSM_ROOT}/lib/core/ui.sh" ]]; then source "${LSM_ROOT}/lib/core/ui.sh"; fi
if [[ -f "${LSM_ROOT}/lib/installer/deploy.sh" ]]; then source "${LSM_ROOT}/lib/installer/deploy.sh"; fi

log_info "SMART" "Установка модуля мониторинга SMART..."

# 1. Директории
deploy_create_directory "/etc/lsm/modules" "755" "root" "root"

# 2. Systemd юниты
#    Исполняемый файл уже развернут в /opt/lsm/modules/smart/files/check_smart.sh
if [[ -f "${MODULE_DIR}/files/lsm-smart.service" ]]; then
    deploy_install_file "${MODULE_DIR}/files/lsm-smart.service" "/etc/systemd/system/lsm-smart.service" "644" "root" "root"
fi
if [[ -f "${MODULE_DIR}/files/lsm-smart.timer" ]]; then
    deploy_install_file "${MODULE_DIR}/files/lsm-smart.timer" "/etc/systemd/system/lsm-smart.timer" "644" "root" "root"
fi

# 3. Конфигурация (без перезаписи существующей)
if [[ -f "${MODULE_DIR}/templates/smart.conf" ]]; then
    if [[ ! -f "/etc/lsm/modules/smart.conf" ]]; then
        deploy_install_file "${MODULE_DIR}/templates/smart.conf" "/etc/lsm/modules/smart.conf" "640" "root" "root"
    else
        log_warn "SMART" "Конфигурация /etc/lsm/modules/smart.conf уже существует, пропуск перезаписи."
    fi
fi

# 4. Активация таймера
if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload || true
    systemctl enable --now lsm-smart.timer || true
fi

log_success "SMART" "Модуль мониторинга SMART успешно установлен."
