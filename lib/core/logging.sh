#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Библиотека централизованного логирования
# Путь: lib/core/logging.sh
#
# Назначение:
#   Предоставляет единый API логирования для всех компонентов LSM.
#
# Возможности:
#   - вывод сообщений в консоль;
#   - запись сообщений в файл журнала;
#   - поддержка уровней логирования;
#   - автоматическое добавление времени;
#   - разделение сообщений по компонентам системы.
#
# Использование:
#
#   log_info "Система запущена"
#
#   log_info "INSTALLER" "Начало установки"
#
# Результат:
#
#   2026-08-04 18:00:00 [INFO   ] [INSTALLER] Начало установки
#
# Уровни:
#
#   0 ERROR   - критические ошибки
#   1 WARN    - предупреждения
#   2 INFO    - обычная информация
#   3 DEBUG   - отладочные сообщения
# ==============================================================================


set -Eeuo pipefail



#
# Защита от повторной загрузки библиотеки.
#
# Так как библиотеки LSM подключаются через source,
# повторное подключение может привести к переопределению
# функций и переменных.
#

[[ -n "${LSM_LOGGING_LOADED:-}" ]] && return 0

readonly LSM_LOGGING_LOADED=1



#
# Настройки логирования по умолчанию.
#
# Значения можно переопределить до подключения библиотеки:
#
#   LOG_LEVEL=3
#   LSM_LOG_DIR=/custom/path
#
#

: "${LOG_LEVEL:=2}"

: "${LSM_LOG_DIR:=/var/log/lsm}"

: "${LSM_LOG_FILE:=${LSM_LOG_DIR}/lsm.log}"



#
# Нормализация уровня логирования.
#
# Поддерживаются варианты:
#
#   ERROR
#   WARN
#   WARNING
#   INFO
#   DEBUG
#
# и числовые значения:
#
#   0-3
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
# Проверка корректности уровня.
#
# Если указано неизвестное значение,
# используется стандартный уровень INFO.
#

if ! [[ "${LOG_LEVEL}" =~ ^[0-3]$ ]]; then

    LOG_LEVEL=2

fi



#
# Цвета сообщений.
#
# Используются только для консольного вывода.
#
# Если цвета не определены внешней библиотекой colors.sh,
# устанавливаются значения по умолчанию.
#

: "${COLOR_RED:=\033[0;31m}"

: "${COLOR_GREEN:=\033[0;32m}"

: "${COLOR_YELLOW:=\033[0;33m}"

: "${COLOR_BLUE:=\033[0;34m}"

: "${COLOR_MAGENTA:=\033[0;35m}"

: "${COLOR_RESET:=\033[0m}"



#
# Получение текущего времени.
#
# Формат:
#
#   YYYY-MM-DD HH:MM:SS
#

_timestamp()
{
    date '+%Y-%m-%d %H:%M:%S'
}



#
# Внутренняя функция вывода.
#
# Не вызывается напрямую пользователем.
#
# Аргументы:
#
#   $1 - числовой уровень сообщения
#   $2 - цвет
#   $3 - текстовый уровень
#   $4 - компонент
#   $5 - сообщение
#

_log()
{

    local level="$1"

    local color="$2"

    local label="$3"

    local component="$4"

    local message="$5"



    #
    # Проверка уровня.
    #
    # Например:
    #
    # LOG_LEVEL=2
    #
    # Показывает:
    # ERROR
    # WARN
    # INFO
    #
    # Но скрывает:
    # DEBUG
    #

    if (( LOG_LEVEL < level )); then

        return 0

    fi



    local ts

    ts="$(_timestamp)"



    #
    # Формирование сообщения для консоли.
    #
    # %b используется для обработки ANSI-кодов цветов.
    #

    local console_out

    console_out=$(printf "%b%s [%-7s] [%s]%b %s\n" \
        "${color}" \
        "${ts}" \
        "${label}" \
        "${component}" \
        "${COLOR_RESET}" \
        "${message}")



    #
    # Ошибки выводятся в stderr.
    #
    # Остальные сообщения идут в stdout.
    #

    if [[ "${label}" == "ERROR" ]]; then

        echo -e "${console_out}" >&2

    else

        echo -e "${console_out}"

    fi



    #
    # Запись сообщения в файл журнала.
    #
    # Ошибка записи журнала не должна ломать работу LSM.
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
# Внутренний разбор аргументов.
#
# Поддерживаются два варианта вызова:
#
# Вариант 1:
#
#   log_info "Сообщение"
#
# Компонент автоматически:
#
#   SYSTEM
#
#
# Вариант 2:
#
#   log_info "MODULE" "Сообщение"
#
# Компонент:
#
#   MODULE
#

_parse_log_args()
{

    local level="$1"

    local color="$2"

    local label="$3"


    shift 3



    local component="SYSTEM"

    local message=""



    #
    # Если передано два и более аргумента,
    # первый считается именем компонента.
    #

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
# Публичный API LSM.
#
# Эти функции используются всеми модулями проекта.
#



#
# Критическая ошибка.
#

log_error()
{

    _parse_log_args \
        0 \
        "${COLOR_RED}" \
        "ERROR" \
        "$@"

}



#
# Предупреждение.
#

log_warn()
{

    _parse_log_args \
        1 \
        "${COLOR_YELLOW}" \
        "WARN" \
        "$@"

}



#
# Информационное сообщение.
#

log_info()
{

    _parse_log_args \
        2 \
        "${COLOR_BLUE}" \
        "INFO" \
        "$@"

}



#
# Успешное завершение операции.
#
# Использует уровень INFO,
# так как успешные события должны быть видны
# при стандартном режиме работы.
#

log_success()
{

    _parse_log_args \
        2 \
        "${COLOR_GREEN}" \
        "SUCCESS" \
        "$@"

}



#
# Отладочная информация.
#
# Показывается только при:
#
#   LOG_LEVEL=3
#

log_debug()
{

    _parse_log_args \
        3 \
        "${COLOR_MAGENTA}" \
        "DEBUG" \
        "$@"

}
