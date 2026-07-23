#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Библиотека управления службами Systemd
# Путь: lib/installer/services.sh
# ==============================================================================

set -Eeuo pipefail

# Защита от повторного подключения файла
[[ -n "${LSM_SERVICES_LOADED:-}" ]] && return 0
readonly LSM_SERVICES_LOADED=1

#
# Проверка существования юнита Systemd
#
services_exists() {
    local unit="${1:-}"

    if [[ -z "${unit}" ]]; then
        return 1
    fi

    # Защита от pipefail при вызове systemctl
    { systemctl list-unit-files "${unit}" 2>/dev/null || true; } | grep -q "^${unit}"
}

#
# Проверка, включена ли служба в автозапуск (enabled)
#
services_is_enabled() {
    local unit="${1:-}"

    if [[ -z "${unit}" ]]; then
        return 1
    fi

    systemctl is-enabled "${unit}" >/dev/null 2>&1
}

#
# Проверка, запущен ли сервис в данный момент (active)
#
services_is_active() {
    local unit="${1:-}"

    if [[ -z "${unit}" ]]; then
        return 1
    fi

    systemctl is-active "${unit}" >/dev/null 2>&1
}

#
# Перечитывание конфигурации демон-менеджера Systemd
#
services_daemon_reload() {
    if declare -f log_info >/dev/null 2>&1; then
        log_info "SERVICES" "Перезагрузка конфигурации Systemd (daemon-reload)..."
    else
        echo "[INFO] Перезагрузка конфигурации Systemd..."
    fi

    systemctl daemon-reload
}

#
# Включение автозапуска службы
#
services_enable() {
    local unit="${1:-}"

    if [[ -z "${unit}" ]]; then
        return 1
    fi

    if services_is_enabled "${unit}"; then
        if declare -f log_info >/dev/null 2>&1; then
            log_info "SERVICES" "Служба уже включена в автозапуск: ${unit}"
        fi
        return 0
    fi

    if declare -f log_info >/dev/null 2>&1; then
        log_info "SERVICES" "Включение автозапуска для ${unit}"
    fi

    systemctl enable "${unit}"
}

#
# Исключение службы из автозапуска
#
services_disable() {
    local unit="${1:-}"

    if [[ -z "${unit}" ]]; then
        return 1
    fi

    if ! services_is_enabled "${unit}"; then
        if declare -f log_info >/dev/null 2>&1; then
            log_info "SERVICES" "Служба уже отключена из автозапуска: ${unit}"
        fi
        return 0
    fi

    if declare -f log_info >/dev/null 2>&1; then
        log_info "SERVICES" "Отключение автозапуска для ${unit}"
    fi

    systemctl disable "${unit}"
}

#
# Запуск службы
#
services_start() {
    local unit="${1:-}"

    if [[ -z "${unit}" ]]; then
        return 1
    fi

    if services_is_active "${unit}"; then
        if declare -f log_info >/dev/null 2>&1; then
            log_info "SERVICES" "Служба уже запущена: ${unit}"
        fi
        return 0
    fi

    if declare -f log_info >/dev/null 2>&1; then
        log_info "SERVICES" "Запуск службы ${unit}"
    fi

    systemctl start "${unit}"
}

#
# Остановка службы
#
services_stop() {
    local unit="${1:-}"

    if [[ -z "${unit}" ]]; then
        return 1
    fi

    if ! services_is_active "${unit}"; then
        if declare -f log_info >/dev/null 2>&1; then
            log_info "SERVICES" "Служба уже остановлена: ${unit}"
        fi
        return 0
    fi

    if declare -f log_info >/dev/null 2>&1; then
        log_info "SERVICES" "Остановка службы ${unit}"
    fi

    systemctl stop "${unit}"
}

#
# Перезапуск службы
#
services_restart() {
    local unit="${1:-}"

    if [[ -z "${unit}" ]]; then
        return 1
    fi

    if declare -f log_info >/dev/null 2>&1; then
        log_info "SERVICES" "Перезапуск службы ${unit}"
    fi

    systemctl restart "${unit}"
}

#
# Перезагрузка конфигурации службы (reload)
#
services_reload() {
    local unit="${1:-}"

    if [[ -z "${unit}" ]]; then
        return 1
    fi

    if declare -f log_info >/dev/null 2>&1; then
        log_info "SERVICES" "Перезагрузка конфигурации службы ${unit}"
    fi

    systemctl reload "${unit}"
}

#
# Включение автозапуска и немедленный запуск службы
#
services_enable_and_start() {
    local unit="${1:-}"

    if [[ -z "${unit}" ]]; then
        return 1
    fi

    services_enable "${unit}"
    services_start "${unit}"
}

#
# Остановка службы и отключение из автозапуска
#
services_stop_and_disable() {
    local unit="${1:-}"

    if [[ -z "${unit}" ]]; then
        return 1
    fi

    services_stop "${unit}"
    services_disable "${unit}"
}
