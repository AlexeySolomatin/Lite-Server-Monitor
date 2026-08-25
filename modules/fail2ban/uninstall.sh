#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Скрипт удаления модуля мониторинга Fail2Ban
# Путь: modules/fail2ban/uninstall.sh
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
# Базовые библиотеки (подключаются условно)
#
if [[ -f "${LSM_ROOT}/lib/core/logging.sh" ]]; then
    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/core/logging.sh"
fi

if [[ -f "${LSM_ROOT}/lib/installer/deploy.sh" ]]; then
    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/installer/deploy.sh"
fi

#
# Резервные функции журналирования на случай,
# если библиотеки ядра недоступны
#

if ! declare -F log_info >/dev/null 2>&1; then
    log_info() { printf '%s\n' "$*"; }
fi

if ! declare -F log_warn >/dev/null 2>&1; then
    log_warn() { printf '%s\n' "$*" >&2; }
fi

if ! declare -F log_error >/dev/null 2>&1; then
    log_error() { printf '%s\n' "$*" >&2; }
fi

if ! declare -F log_success >/dev/null 2>&1; then
    log_success() { printf '%s\n' "$*"; }
fi

readonly MODULE_NAME="fail2ban"
readonly LOG_COMPONENT="FAIL2BAN"
readonly STATE_DIR="/var/lib/lsm/state"

#
# 1. Остановка и отключение systemd
#
if command -v systemctl >/dev/null 2>&1; then
    # Сначала останавливаем и отключаем таймер (избегаем warning от systemd)
    systemctl disable --now "lsm-${MODULE_NAME}.timer" 2>/dev/null || true

    # останавливаем службу, если она выполнялась в данный момент
    systemctl stop "lsm-${MODULE_NAME}.service" 2>/dev/null || true
fi

#
# 2. Удаление unit-файлов systemd
#
deploy_remove_file "/etc/systemd/system/lsm-${MODULE_NAME}.service"
deploy_remove_file "/etc/systemd/system/lsm-${MODULE_NAME}.timer"

#
# 3. Перезагрузка конфигурации systemd (строго ПОСЛЕ удаления файлов unit-ов)
#
if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload 2>/dev/null || true
fi

#
# 4. Удаление конфигурационного файла модуля
#
deploy_remove_file "/etc/lsm/modules/${MODULE_NAME}.conf"

#
# 5. Удаление файлов состояния и блокировки
#
deploy_remove_file "${STATE_DIR}/${MODULE_NAME}_bans"
deploy_remove_file "${STATE_DIR}/${MODULE_NAME}_check.lock"
deploy_remove_file "${STATE_DIR}/${MODULE_NAME}.state"

#
# 6. Удаление директории модуля
#
deploy_remove_directory "${LSM_ROOT}/modules/${MODULE_NAME}"

#
# 7. Финальный лог
#
log_success "${LOG_COMPONENT}" "Модуль мониторинга Fail2Ban успешно удалён."
