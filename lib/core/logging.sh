#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Библиотека логирования (Раздел 8 Контекста)
# Путь: lib/core/logging.sh
# ==============================================================================

set -Eeuo pipefail

# Уровень логирования по умолчанию:
# 0 = ERROR
# 1 = WARN
# 2 = INFO / SUCCESS
# 3 = DEBUG

: "${LOG_LEVEL:=2}"
: "${LSM_LOG_DIR:=/var/log/lsm}"
: "${LSM_LOG_FILE:=${LSM_LOG_DIR}/lsm.log}"

# Цветовые коды по умолчанию (если не объявлены в окружении)
: "${COLOR_RED:=\033[0;31m}"
: "${COLOR_GREEN:=\033[0;32m}"
: "${COLOR_YELLOW:=\033[0;33m}"
: "${COLOR_BLUE:=\033[0;34m}"
: "${COLOR_MAGENTA:=\033[0;35m}"
: "${COLOR_RESET:=\033[0m}"

_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

_log() {
    local level="$1"
    local color="$2"
    local label="$3"
    local component="$4"
    local message="$5"

    if (( LOG_LEVEL < level )); then
        return
    fi

    local ts
    ts="$(_timestamp)"

    # Форматирование для вывода в консоль (с цветовым выделением)
    local console_out
    console_out=$(printf "%b%s [%-7s] [%s]%b %s\n" \
        "${color}" \
        "${ts}" \
        "${label}" \
        "${component}" \
        "${COLOR_RESET}" \
        "${message}")

    # Вывод в stdout/stderr
    if [[ "${label}" == "ERROR" ]]; then
        echo -e "${console_out}" >&2
    else
        echo -e "${console_out}"
    fi

    # Дублирование записи в файл лога /var/log/lsm/lsm.log (без ANSI-кодов)
    if [[ -d "${LSM_LOG_DIR}" || -w "/var/log" ]]; then
        mkdir -p "${LSM_LOG_DIR}" 2>/dev/null || true
        local plain_entry
        plain_entry=$(printf "%s [%-7s] [%s] %s\n" "${ts}" "${label}" "${component}" "${message}")
        echo "${plain_entry}" >> "${LSM_LOG_FILE}" 2>/dev/null || true
    fi
}

# Вспомогательный разбор аргументов: [компонент] сообщение ИЛИ сообщение
_parse_log_args() {
    local level="$1"
    local color="$2"
    local label="$3"
    shift 3

    local component="SYSTEM"
    local message=""

    if [[ $# -ge 2 ]]; then
        component="$1"
        shift
        message="$*"
    elif [[ $# -eq 1 ]]; then
        message="$1"
    fi

    _log "${level}" "${color}" "${label}" "${component}" "${message}"
}

log_error() {
    _parse_log_args 0 "${COLOR_RED}" "ERROR" "$@"
}

log_warn() {
    _parse_log_args 1 "${COLOR_YELLOW}" "WARN" "$@"
}

log_info() {
    _parse_log_args 2 "${COLOR_BLUE}" "INFO" "$@"
}

log_success() {
    _parse_log_args 2 "${COLOR_GREEN}" "SUCCESS" "$@"
}

log_debug() {
    _parse_log_args 3 "${COLOR_MAGENTA}" "DEBUG" "$@"
}
