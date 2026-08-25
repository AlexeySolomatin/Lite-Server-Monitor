#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Инсталлятор модуля контроля температуры
# -----------------------------------------------------------------------------

set -Eeuo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LSM_ROOT="${LSM_ROOT:-/opt/lsm}"

if [[ -f "${LSM_ROOT}/lib/core/common.sh" ]]; then source "${LSM_ROOT}/lib/core/common.sh"; fi
if [[ -f "${LSM_ROOT}/lib/core/ui.sh" ]]; then source "${LSM_ROOT}/lib/core/ui.sh"; fi
if [[ -f "${LSM_ROOT}/lib/installer/deploy.sh" ]]; then source "${LSM_ROOT}/lib/installer/deploy.sh"; fi

log_info "TEMPERATURE" "Установка модуля контроля температуры..."

# 1. Директории
deploy_create_directory "/etc/lsm/modules" "755" "root" "root"

# 2. Systemd юниты
#    Исполняемый файл уже развернут в /opt/lsm/modules/temperature/files/check_temperature.sh
if [[ -f "${MODULE_DIR}/files/lsm-temperature.service" ]]; then
    deploy_install_file "${MODULE_DIR}/files/lsm-temperature.service" "/etc/systemd/system/lsm-temperature.service" "644" "root" "root"
fi
if [[ -f "${MODULE_DIR}/files/lsm-temperature.timer" ]]; then
    deploy_install_file "${MODULE_DIR}/files/lsm-temperature.timer" "/etc/systemd/system/lsm-temperature.timer" "644" "root" "root"
fi

# 3. Конфигурация (без перезаписи существующей)
if [[ -f "${MODULE_DIR}/templates/temperature.conf" ]]; then
    if [[ ! -f "/etc/lsm/modules/temperature.conf" ]]; then
        deploy_install_file "${MODULE_DIR}/templates/temperature.conf" "/etc/lsm/modules/temperature.conf" "640" "root" "root"
    else
        log_warn "TEMPERATURE" "Конфигурация /etc/lsm/modules/temperature.conf уже существует, пропуск перезаписи."
    fi
fi

# 4. Активация таймера
if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload || true
    if ! systemctl enable --now lsm-temperature.timer; then
        if declare -f log_warn >/dev/null 2>&1; then
            log_warn "TEMPERATURE" "Не удалось активировать таймер lsm-temperature.timer. Диагностика: systemctl status lsm-temperature.timer"
        else
            echo "Предупреждение: не удалось активировать таймер lsm-temperature.timer." >&2
        fi
    fi
fi

log_success "TEMPERATURE" "Модуль контроля температуры успешно установлен."
