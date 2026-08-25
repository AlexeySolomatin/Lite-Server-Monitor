#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Шаг 06: Службы и перечитывание конфигурации Systemd
#
# Путь:
#   installer/steps/06_services.sh
#
# Назначение:
#   Перечитывание конфигурации Systemd после установки LSM.
#
# ==============================================================================

set -Eeuo pipefail

readonly SERVICES_STEP_COMPONENT="SERVICES"

step_services()
{
    log_info "${SERVICES_STEP_COMPONENT}" \
        "Перезагрузка конфигурации Systemd."

    #
    # Проверяем наличие systemd
    #
    if ! command -v systemctl >/dev/null 2>&1; then
        log_warn "${SERVICES_STEP_COMPONENT}" \
            "Systemd отсутствует. Пропуск daemon-reload."
        return 0
    fi

    #
    # Гарантируем подгрузку библиотеки services.sh
    #
    if [[ -f "${LSM_ROOT}/lib/installer/services.sh" ]]; then
        source "${LSM_ROOT}/lib/installer/services.sh"
    fi

    #
    # Проверяем наличие функций из библиотеки
    #
    if ! declare -f services_daemon_reload >/dev/null 2>&1; then
        log_error "${SERVICES_STEP_COMPONENT}" \
            "Библиотека services.sh не загружена."
        return 1
    fi

    if services_daemon_reload; then
        log_success "${SERVICES_STEP_COMPONENT}" \
            "Systemd успешно перечитал конфигурацию."
    else
        log_error "${SERVICES_STEP_COMPONENT}" \
            "Ошибка выполнения daemon-reload."
        return 1
    fi

    return 0
}

#
# Автономный запуск
#
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
    export LSM_ROOT

    source "${LSM_ROOT}/lib/core/common.sh"
    source "${LSM_ROOT}/lib/core/logging.sh"
    source "${LSM_ROOT}/lib/installer/services.sh"

    step_services
fi
