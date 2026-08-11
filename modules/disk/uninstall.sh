#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Скрипт удаление модуля мониторинга дискового пространства
# Путь: modules/disk/uninstall.sh
# ==============================================================================

set -Eeuo pipefail

#
# Корень LSM
#
if [[ -z "${LSM_ROOT:-}" ]]; then
    LSM_ROOT="/opt/lsm"
fi
export LSM_ROOT

#
# Базовые библиотеки (согласно UNINSTALL CONTRACT)
#
source "${LSM_ROOT}/lib/core/logging.sh"
source "${LSM_ROOT}/lib/installer/deploy.sh"

readonly MODULE_NAME="disk"
readonly LOG_COMPONENT="DISK"

#
# 1. Остановка и отключение systemd таймера и сервиса
#
if command -v systemctl >/dev/null 2>&1; then
    # Сначала останавливаем и отключаем ТАЙМЕР (чтобы исключить новые запуски)
    systemctl disable --now "lsm-${MODULE_NAME}.timer" 2>/dev/null || true

    # Если служба сейчас выполняется в этот конкретный момент — останавливаем её
    systemctl stop "lsm-${MODULE_NAME}.service" 2>/dev/null || true
fi

#
# 2. Удаление unit-файлов systemd
#
deploy_remove_file "/etc/systemd/system/lsm-${MODULE_NAME}.service"
deploy_remove_file "/etc/systemd/system/lsm-${MODULE_NAME}.timer"

#
# 3. Обновление конфигурации systemd (ПОСЛЕ удаления файлов с диска!)
#
if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload 2>/dev/null || true
fi

#
# 4. Удаление каталога модуля
#
deploy_remove_directory "${LSM_ROOT}/modules/${MODULE_NAME}"

#
# 5. Уведомление об успешном удалении
#
log_success "${LOG_COMPONENT}" "Модуль ${MODULE_NAME} успешно удалён."
