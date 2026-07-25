#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Библиотека логирования
# Путь: lib/core/logging.sh
# ==============================================================================

set -Eeuo pipefail


[[ -n "${LSM_LOGGING_LOADED:-}" ]] && return 0
readonly LSM_LOGGING_LOADED=1



#
# Настройки логирования
#
# Уровни:
#
# 0 ERROR
# 1 WARN
# 2 INFO
# 3 DEBUG
#

: "${LOG_LEVEL:=2}"

: "${LSM_LOG_DIR:=/var/log/lsm}"
: "${LSM_LOG_FILE:=${LSM_LOG_DIR}/lsm.log}"



#
# Нормализация LOG_LEVEL
#
# Поддержка:
# INFO
# WARN
# ERROR
# DEBUG
# 0-3
#

case "${LOG_LEVEL^^}" in

    ERROR)
        LOG_LEVEL=0
        ;;

    WARN|WARNING)
        LOG_LEVEL=1
        ;;

    INFO)
        LOG_LEVEL=2
        ;;

    DEBUG)
        LOG_LEVEL=3
        ;;

esac



#
# Проверка значения
#

if ! [[ "${LOG_LEVEL}" =~ ^[0-3]$ ]]; then

    LOG_LEVEL=2

fi



#
# Цвета
#

: "${COLOR_RED:=\033[0;31m}"
: "${COLOR_GREEN:=\033[0;32m}"
: "${COLOR_YELLOW:=\033[0;33m}"
: "${COLOR_BLUE:=\033[0;34m}"
: "${COLOR_MAGENTA:=\033[0;35m}"
: "${COLOR_RESET:=\033[0m}"



#
# Время
#

_timestamp()
{
    date '+%Y-%m-%d %H:%M:%S'
}



#
# Внутренний вывод
#

_log()
{

    local level="$1"
    local color="$2"
    local label="$3"
    local component="$4"
    local message="$5"



    if (( LOG_LEVEL < level )); then

        return 0

    fi



    local ts

    ts="$(_timestamp)"



    local console_out

    console_out=$(printf "%b%s [%-7s] [%s]%b %s\n" \
        "${color}" \
        "${ts}" \
        "${label}" \
        "${component}" \
        "${COLOR_RESET}" \
        "${message}")



    if [[ "${label}" == "ERROR" ]]; then

        echo -e "${console_out}" >&2

    else

        echo -e "${console_out}"

    fi



    #
    # Запись файла
    #

    mkdir -p "${LSM_LOG_DIR}" 2>/dev/null || true


    local plain_entry

    plain_entry=$(printf "%s [%-7s] [%s] %s\n" \
        "${ts}" \
        "${label}" \
        "${component}" \
        "${message}")


    echo "${plain_entry}" >> "${LSM_LOG_FILE}" 2>/dev/null || true

}



#
# Разбор аргументов
#
# Варианты:
#
# log_info "message"
#
# log_info MODULE "message"
#

_parse_log_args()
{

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



    _log \
        "${level}" \
        "${color}" \
        "${label}" \
        "${component}" \
        "${message}"

}



#
# Public API
#

log_error()
{
    _parse_log_args \
        0 \
        "${COLOR_RED}" \
        "ERROR" \
        "$@"
}



log_warn()
{
    _parse_log_args \
        1 \
        "${COLOR_YELLOW}" \
        "WARN" \
        "$@"
}



log_info()
{
    _parse_log_args \
        2 \
        "${COLOR_BLUE}" \
        "INFO" \
        "$@"
}



log_success()
{
    _parse_log_args \
        2 \
        "${COLOR_GREEN}" \
        "SUCCESS" \
        "$@"
}



log_debug()
{
    _parse_log_args \
        3 \
        "${COLOR_MAGENTA}" \
        "DEBUG" \
        "$@"
}
