#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Библиотека централизованного логирования
#
# Путь:
#   lib/core/logging.sh
#
# Назначение:
#   Единый API журналирования для всех компонентов LSM.
#
# Возможности:
#
#   - вывод сообщений в терминал;
#   - запись событий в журнал;
#   - уровни ERROR/WARN/INFO/SUCCESS/DEBUG;
#   - поддержка компонентов;
#   - безопасная работа без root;
#   - совместимость с CLI, installer и module_api.
#
#
# Примеры:
#
#   log_info "Система запущена"
#
#   log_info "SMART" "Проверка диска завершена"
#
#   LSM_COMPONENT="INSTALLER"
#   log_success "Модуль установлен"
#
#
# Формат файла журнала:
#
#   2026-08-05 06:00:00 [INFO   ] [SMART] Проверка завершена
#
# ==============================================================================


set -Eeuo pipefail



#
# Защита от повторной загрузки
#

[[ -n "${LSM_LOGGING_LOADED:-}" ]] && return 0

readonly LSM_LOGGING_LOADED=1



#
# Настройки по умолчанию
#

: "${LOG_LEVEL:=2}"

: "${LSM_COMPONENT:=SYSTEM}"

: "${LSM_LOG_DIR:=/var/log/lsm}"

: "${LSM_LOG_FILE:=${LSM_LOG_DIR}/lsm.log}"



#
# Уровни:
#
# 0 ERROR
# 1 WARN
# 2 INFO
# 3 DEBUG
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



if ! [[ "${LOG_LEVEL}" =~ ^[0-3]$ ]]; then

    LOG_LEVEL=2

fi



#
# Подключение цветов.
#
# Если colors.sh уже загружен,
# используем его значения.
#

: "${COLOR_RED:=\033[31m}"

: "${COLOR_GREEN:=\033[32m}"

: "${COLOR_YELLOW:=\033[33m}"

: "${COLOR_BLUE:=\033[34m}"

: "${COLOR_MAGENTA:=\033[35m}"

: "${COLOR_RESET:=\033[0m}"



#
# Время сообщения
#

_log_timestamp()
{
    date '+%Y-%m-%d %H:%M:%S'
}



#
# Проверка возможности записи журнала
#

_prepare_log_directory()
{

    if [[ -d "${LSM_LOG_DIR}" ]]; then

        return 0

    fi



    mkdir -p "${LSM_LOG_DIR}" 2>/dev/null || true


    if [[ ! -d "${LSM_LOG_DIR}" ]]; then

        LSM_LOG_DIR="/tmp/lsm"

        LSM_LOG_FILE="${LSM_LOG_DIR}/lsm.log"


        mkdir -p "${LSM_LOG_DIR}" 2>/dev/null || true

    fi

}



#
# Внутренняя функция записи
#

_log_write_file()
{

    local entry="$1"


    _prepare_log_directory


    echo "${entry}" >> "${LSM_LOG_FILE}" 2>/dev/null || true

}



#
# Основная функция логирования
#
# Аргументы:
#
#   $1 уровень
#   $2 цвет
#   $3 название уровня
#   $4 компонент
#   $5 сообщение
#

_log()
{

    local level="$1"

    local color="$2"

    local label="$3"

    local component="$4"

    local message="$5"



    #
    # Проверяем уровень вывода
    #

    if (( LOG_LEVEL < level )); then

        return 0

    fi



    local timestamp

    timestamp="$(_log_timestamp)"



    #
    # Текст без цветов.
    # Используется для файла.
    #

    local plain


    plain=$(printf "%s [%-7s] [%s] %s" \
        "${timestamp}" \
        "${label}" \
        "${component}" \
        "${message}")



    _log_write_file "${plain}"



    #
    # Цветной вывод в терминал.
    #

    if [[ -t 1 ]]; then


        local console


        console=$(printf "%b%s [%-7s] [%s]%b %s" \
            "${color}" \
            "${timestamp}" \
            "${label}" \
            "${component}" \
            "${COLOR_RESET}" \
            "${message}")


        if [[ "${label}" == "ERROR" ]]; then

            printf "%b\n" "${console}" >&2

        else

            printf "%b\n" "${console}"

        fi


    else


        printf "%s\n" "${plain}"


    fi

}



#
# Разбор аргументов
#
# Поддержка:
#
#   log_info "текст"
#
#   log_info "MODULE" "текст"
#

_parse_log_args()
{

    local level="$1"

    local color="$2"

    local label="$3"


    shift 3



    local component="${LSM_COMPONENT}"

    local message=""



    if [[ $# -ge 2 ]]; then


        component="$1"

        shift


        message="$*"



    elif [[ $# -eq 1 ]]; then


        message="$1"



    else


        message=""

    fi



    _log \
        "${level}" \
        "${color}" \
        "${label}" \
        "${component}" \
        "${message}"

}



#
# Публичный API
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



#
# Совместимость с module_api
#

module_log_info()
{
    log_info "$@"
}


module_log_warn()
{
    log_warn "$@"
}


module_log_error()
{
    log_error "$@"
}


module_log_success()
{
    log_success "$@"
}
