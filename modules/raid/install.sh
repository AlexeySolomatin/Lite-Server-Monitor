#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Инсталлятор модуля мониторинга RAID
# -----------------------------------------------------------------------------

set -Eeuo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LSM_ROOT="${LSM_ROOT:-/opt/lsm}"

# Загрузка библиотек ядра
if [[ -f "${LSM_ROOT}/lib/core/common.sh" ]]; then source "${LSM_ROOT}/lib/core/common.sh"; fi
if [[ -f "${LSM_ROOT}/lib/core/ui.sh" ]]; then source "${LSM_ROOT}/lib/core/ui.sh"; fi
if [[ -f "${LSM_ROOT}/lib/installer/deploy.sh" ]]; then source "${LSM_ROOT}/lib/installer/deploy.sh"; fi

log_info "RAID" "Установка модуля мониторинга RAID..."

# 1. Создание целевых каталогов
deploy_create_directory "/etc/lsm/modules" "755" "root" "root"

# 2. Установка юнитов Systemd
#    Исполняемый файл уже развернут в /opt/lsm/modules/raid/files/check_raid.sh
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

# 3. Развертывание конфигурации модуля (без перезаписи существующей)
if [[ -f "${MODULE_DIR}/templates/raid.conf" ]]; then
    if [[ ! -f "/etc/lsm/modules/raid.conf" ]]; then
        deploy_install_file \
            "${MODULE_DIR}/templates/raid.conf" \
            "/etc/lsm/modules/raid.conf" \
            "640" "root" "root"
    else
        log_warn "RAID" "Конфигурация /etc/lsm/modules/raid.conf уже существует, пропуск перезаписи."
    fi
fi

# 4. Регистрация и запуск в systemd
if command -v systemctl >/dev/null 2>&1; then
    log_info "RAID" "Перезагрузка конфигурации systemd и активация lsm-raid.timer..."
    systemctl daemon-reload || true
    systemctl enable --now lsm-raid.timer || true
fi

log_success "RAID" "Модуль мониторинга RAID успешно установлен."
