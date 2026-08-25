#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Инсталлятор модуля мониторинга дисков
# Путь: modules/disk/install.sh
# ==============================================================================

set -Eeuo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Единый корень установки LSM
LSM_ROOT="${LSM_ROOT:-/opt/lsm}"

#
# Безопасная подгрузка библиотек ядра из исходников
#
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

log_info "DISK" "Установка модуля мониторинга дисков..."

# 1. Создание директории конфигурации
deploy_create_directory "/etc/lsm/modules" "755" "root" "root"

# 2. Манифест модуля.
#    Отдельное копирование манифеста не требуется:
#    полный инсталлятор развертывает все дерево проекта в /opt/lsm,
#    включая modules/disk/manifest.conf.

# 3. Установка юнитов systemd
if [[ -f "${MODULE_DIR}/files/lsm-disk.service" ]]; then
    deploy_install_file \
        "${MODULE_DIR}/files/lsm-disk.service" \
        "/etc/systemd/system/lsm-disk.service" \
        "644" "root" "root"
fi

if [[ -f "${MODULE_DIR}/files/lsm-disk.timer" ]]; then
    deploy_install_file \
        "${MODULE_DIR}/files/lsm-disk.timer" \
        "/etc/systemd/system/lsm-disk.timer" \
        "644" "root" "root"
fi

# 4. Настройка конфигурационных файлов
if [[ -f "${MODULE_DIR}/templates/disk.conf" ]]; then
    if [[ ! -f "/etc/lsm/modules/disk.conf" ]]; then
        deploy_install_file \
            "${MODULE_DIR}/templates/disk.conf" \
            "/etc/lsm/modules/disk.conf" \
            "640" "root" "root"
    else
        log_warn "DISK" "Конфигурация /etc/lsm/modules/disk.conf уже существует, пропуск перезаписи."
    fi
fi

# 5. Перезапуск конфигурации systemd и активация таймера
if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload || true
    systemctl enable --now lsm-disk.timer || true
fi

log_success "DISK" "Модуль мониторинга дисков успешно установлен."
