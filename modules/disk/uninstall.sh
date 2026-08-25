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
if [[ -f "${LSM_ROOT}/lib/core/logging.sh" ]]; then
    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/core/logging.sh"
fi

if [[ -f "${LSM_ROOT}/lib/installer/deploy.sh" ]]; then
    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/installer/deploy.sh"
fi

readonly MODULE_NAME="disk"
readonly LOG_COMPONENT="DISK"
readonly STATE_DIR="/var/lib/lsm/state"

#
# Резервные реализации на случай отсутствия библиотек.
#

if ! declare -F deploy_remove_file >/dev/null 2>&1; then
    deploy_remove_file() {
        if [[ -f "${1:-}" || -L "${1:-}" ]]; then
            rm -f -- "${1}"
        fi
    }
fi

if ! declare -F deploy_remove_directory >/dev/null 2>&1; then
    deploy_remove_directory() {
        if [[ -d "${1:-}" ]]; then
            rm -rf -- "${1}"
        fi
    }
fi

if ! declare -F log_info >/dev/null 2>&1; then
    log_info() { printf '[INFO] [%s] %s\n' "${LOG_COMPONENT}" "$*"; }
fi

if ! declare -F log_warn >/dev/null 2>&1; then
    log_warn() { printf '[WARN] [%s] %s\n' "${LOG_COMPONENT}" "$*" >&2; }
fi

if ! declare -F log_success >/dev/null 2>&1; then
    log_success() { printf '[OK] [%s] %s\n' "${LOG_COMPONENT}" "$*"; }
fi

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
# 4. Удаление конфигурационного файла модуля
#
deploy_remove_file "/etc/lsm/modules/${MODULE_NAME}.conf"

#
# 5. Очистка файлов состояния:
#
#    disk.state      — состояние уведомлений (notify);
#    disk_check.lock — файл блокировки.
#

deploy_remove_file "${STATE_DIR}/${MODULE_NAME}.state"

deploy_remove_file "${STATE_DIR}/${MODULE_NAME}_check.lock"

#
# 6. Удаление каталога модуля
#
deploy_remove_directory "${LSM_ROOT}/modules/${MODULE_NAME}"

#
# 7. Уведомление об успешном удалении
#
log_success "${LOG_COMPONENT}" "Модуль ${MODULE_NAME} успешно удалён."
