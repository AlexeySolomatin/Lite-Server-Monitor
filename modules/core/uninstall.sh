#!/usr/bin/env bash

# ==============================================================================
# Lite Server Monitor (LSM)
# Удаление системных юнитов ежедневных отчетов (Модуль Core)
# Путь: modules/core/uninstall.sh
# ==============================================================================

set -Eeuo pipefail

#
# Корень LSM
#

if [[ -z "${LSM_ROOT:-}" ]]; then
    LSM_ROOT="/opt/lsm"
fi

export LSM_ROOT

readonly MODULE_NAME="core"
readonly LOG_COMPONENT="CORE"

#
# Базовые библиотеки подключаются условно,
# чтобы удаление не падало при недоступных файлах библиотек.
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
# Резервные реализации на случай отсутствия библиотек.
#

if ! declare -F deploy_remove_file >/dev/null 2>&1; then

    deploy_remove_file()
    {
        if [[ -f "${1:-}" || -L "${1:-}" ]]; then
            rm -f -- "${1}"
        fi
    }

fi

if ! declare -F log_info >/dev/null 2>&1; then

    log_info()
    {
        printf '[INFO] [%s] %s\n' "${LOG_COMPONENT}" "$*"
    }

fi

if ! declare -F log_success >/dev/null 2>&1; then

    log_success()
    {
        printf '[OK] [%s] %s\n' "${LOG_COMPONENT}" "$*"
    }

fi

#
# Пути systemd
#

readonly SYSTEMD_DIR="/etc/systemd/system"

#
# Удаление системных юнитов отчетов LSM
#

log_info \
    "${LOG_COMPONENT}" \
    "Остановка и удаление системных юнитов отчетов LSM..."

#
# 1. Остановка и отключение таймера
#

if command -v systemctl >/dev/null 2>&1; then

    systemctl disable --now lsm-report.timer 2>/dev/null || true

    #
    # На случай, если сервис выполняется непосредственно сейчас
    #

    systemctl stop lsm-report.service 2>/dev/null || true

fi

#
# 2. Удаление файлов юнитов
#

deploy_remove_file \
    "${SYSTEMD_DIR}/lsm-report.service"

deploy_remove_file \
    "${SYSTEMD_DIR}/lsm-report.timer"

#
# 3. Перезагрузка конфигурации systemd
#
# Выполняется только после удаления файлов unit-ов.
#

if command -v systemctl >/dev/null 2>&1; then

    systemctl daemon-reload 2>/dev/null || true
    systemctl reset-failed 2>/dev/null || true

fi

#
# 4. Итог
#

log_success \
    "${LOG_COMPONENT}" \
    "Юниты lsm-report успешно удалены."
