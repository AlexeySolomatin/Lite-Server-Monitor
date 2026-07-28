#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Библиотека управления службами Systemd
# Путь: lib/installer/services.sh
# ==============================================================================

set -Eeuo pipefail

[[ -n "${LSM_SERVICES_LOADED:-}" ]] && return 0
readonly LSM_SERVICES_LOADED=1

readonly SERVICES_COMPONENT="SERVICES"

#
# Проверка аргумента
#
_services_require_unit()
{
    [[ -n "${1:-}" ]]
}

#
# Проверка существования unit
#
services_exists()
{
    local unit="${1:-}"

    _services_require_unit "${unit}" || return 1

    systemctl list-unit-files "${unit}" 2>/dev/null | grep -q -- "^${unit}"
}

#
# Проверка enabled
#
services_is_enabled()
{
    local unit="${1:-}"

    _services_require_unit "${unit}" || return 1

    systemctl is-enabled "${unit}" >/dev/null 2>&1
}

#
# Проверка active
#
services_is_active()
{
    local unit="${1:-}"

    _services_require_unit "${unit}" || return 1

    systemctl is-active "${unit}" >/dev/null 2>&1
}

#
# daemon-reload
#
services_daemon_reload()
{
    log_info "${SERVICES_COMPONENT}" "Перезагрузка конфигурации Systemd"

    if systemctl daemon-reload; then
        log_success "${SERVICES_COMPONENT}" "Systemd успешно перечитал конфигурацию"
    else
        log_error "${SERVICES_COMPONENT}" "Ошибка daemon-reload"
        return 1
    fi
}

#
# enable
#
services_enable()
{
    local unit="${1:-}"

    _services_require_unit "${unit}" || return 1

    if services_is_enabled "${unit}"; then
        log_info "${SERVICES_COMPONENT}" "Служба уже включена: ${unit}"
        return 0
    fi

    log_info "${SERVICES_COMPONENT}" "Включение автозапуска: ${unit}"

    if systemctl enable "${unit}"; then
        log_success "${SERVICES_COMPONENT}" "Автозапуск включен: ${unit}"
    else
        log_error "${SERVICES_COMPONENT}" "Не удалось включить ${unit}"
        return 1
    fi
}

#
# disable
#
services_disable()
{
    local unit="${1:-}"

    _services_require_unit "${unit}" || return 1

    if ! services_is_enabled "${unit}"; then
        log_info "${SERVICES_COMPONENT}" "Служба уже отключена: ${unit}"
        return 0
    fi

    log_info "${SERVICES_COMPONENT}" "Отключение автозапуска: ${unit}"

    if systemctl disable "${unit}"; then
        log_success "${SERVICES_COMPONENT}" "Автозапуск отключен: ${unit}"
    else
        log_error "${SERVICES_COMPONENT}" "Не удалось отключить ${unit}"
        return 1
    fi
}

#
# start
#
services_start()
{
    local unit="${1:-}"

    _services_require_unit "${unit}" || return 1

    if services_is_active "${unit}"; then
        log_info "${SERVICES_COMPONENT}" "Служба уже запущена: ${unit}"
        return 0
    fi

    log_info "${SERVICES_COMPONENT}" "Запуск службы: ${unit}"

    if systemctl start "${unit}"; then
        log_success "${SERVICES_COMPONENT}" "Служба успешно запущена: ${unit}"
    else
        log_error "${SERVICES_COMPONENT}" "Не удалось запустить ${unit}"
        return 1
    fi
}

#
# stop
#
services_stop()
{
    local unit="${1:-}"

    _services_require_unit "${unit}" || return 1

    if ! services_is_active "${unit}"; then
        log_info "${SERVICES_COMPONENT}" "Служба уже остановлена: ${unit}"
        return 0
    fi

    log_info "${SERVICES_COMPONENT}" "Остановка службы: ${unit}"

    if systemctl stop "${unit}"; then
        log_success "${SERVICES_COMPONENT}" "Служба остановлена: ${unit}"
    else
        log_error "${SERVICES_COMPONENT}" "Не удалось остановить ${unit}"
        return 1
    fi
}

#
# restart
#
services_restart()
{
    local unit="${1:-}"

    _services_require_unit "${unit}" || return 1

    log_info "${SERVICES_COMPONENT}" "Перезапуск службы: ${unit}"

    if systemctl restart "${unit}"; then
        log_success "${SERVICES_COMPONENT}" "Служба перезапущена: ${unit}"
    else
        log_error "${SERVICES_COMPONENT}" "Не удалось перезапустить ${unit}"
        return 1
    fi
}

#
# reload
#
services_reload()
{
    local unit="${1:-}"

    _services_require_unit "${unit}" || return 1

    log_info "${SERVICES_COMPONENT}" "Перезагрузка конфигурации службы: ${unit}"

    if systemctl reload "${unit}"; then
        log_success "${SERVICES_COMPONENT}" "Конфигурация службы обновлена: ${unit}"
    else
        log_error "${SERVICES_COMPONENT}" "Не удалось выполнить reload для ${unit}"
        return 1
    fi
}

#
# enable + start
#
services_enable_and_start()
{
    local unit="${1:-}"

    _services_require_unit "${unit}" || return 1

    services_enable "${unit}"
    services_start "${unit}"
}

#
# stop + disable
#
services_stop_and_disable()
{
    local unit="${1:-}"

    _services_require_unit "${unit}" || return 1

    services_stop "${unit}"
    services_disable "${unit}"
}
