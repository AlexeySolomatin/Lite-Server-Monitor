#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Скрипт удаления модуля контроля входов пользователей
# Путь: modules/login/uninstall.sh
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

readonly MODULE_NAME="login"
readonly LOG_COMPONENT="LOGIN"

#
# 1. Остановка и отключение systemd
#
if command -v systemctl >/dev/null 2>&1; then
    systemctl disable --now "lsm-${MODULE_NAME}.timer" 2>/dev/null || true
    systemctl stop "lsm-${MODULE_NAME}.service" 2>/dev/null || true
fi

#
# 2. Удаление unit-файлов systemd
#
deploy_remove_file "/etc/systemd/system/lsm-${MODULE_NAME}.service"
deploy_remove_file "/etc/systemd/system/lsm-${MODULE_NAME}.timer"

#
# 3. Перезагрузка конфигурации systemd (ПОСЛЕ удаления файлов unit-ов)
#
if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload 2>/dev/null || true
fi

#
# 4. Удаление конфигурационного файла модуля
#
deploy_remove_file "/etc/lsm/modules/${MODULE_NAME}.conf"

#
# 5. Удаление директории модуля
#
deploy_remove_directory "${LSM_ROOT}/modules/${MODULE_NAME}"

#
# 6. Финальный лог
#
log_success "${LOG_COMPONENT}" "Модуль контроля входов пользователей успешно удалён."
