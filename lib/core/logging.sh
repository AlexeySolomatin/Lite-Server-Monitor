#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Библиотека централизованного логирования
#
# Путь:
#   lib/core/logging.sh
#
# Назначение:
#   Единый механизм регистрации событий LSM.
#
# Поддерживаемые уровни:
#
#   ERROR   - критическая ошибка выполнения LSM
#   FAIL    - проверка выполнена, состояние системы неудовлетворительное
#   WARN    - предупреждение
#   SUCCESS - успешное выполнение операции
#   INFO    - информационное сообщение
#   DEBUG   - отладочная информация
#
# Примеры:
#
#   log_info "Запуск проверки системы"
#
#   log_warn "SMART" "Температура диска 48°C"
#
#   log_fail "UPS" "ИБП отключен"
#
# Формат файла журнала:
#
#   2026-08-05 09:40:12 [WARN   ] [SMART] Температура диска 48°C
#
# ==============================================================================


set -Eeuo pipefail



#
# Защита от повторной загрузки библиотеки.
#
# Библиотеки LSM подключаются через source.
# Повторная загрузка может привести к переопределению функций.
#

[[ -n "${LSM_LOGGING_LOADED:-}" ]] && return 0

readonly LSM_LOGGING_LOADED=1



#
# Настройки логирования по умолчанию.
#
# Можно переопределить до загрузки:
#
#   LOG_LEVEL=3
#   LSM_LOG_DIR=/custom/log/path
#

: "${LOG_LEVEL:=2}"

: "${LSM_LOG_DIR:=/var/log/lsm}"

: "${LSM_LOG_FILE:=${LSM_LOG_DIR}/lsm.log}"



#
# Числовые уровни логирования.
#
# Чем меньше число,
# тем выше приоритет сообщения.
#

readonly LOG_LEVEL_ERROR=0
readonly LOG_LEVEL_FAIL=1
readonly LOG_LEVEL_WARN=1
readonly LOG_LEVEL_SUCCESS=2
readonly LOG_LEVEL_INFO=2
readonly LOG_LEVEL_DEBUG=3



#
# Нормализация уровня логирования.
#

case "${LOG_LEVEL^^}" in

    ERROR)
        LOG_LEVEL=${LOG_LEVEL_ERROR}
        ;;

    FAIL)
        LOG_LEVEL=${LOG_LEVEL_FAIL}
        ;;

    WARN|WARNING)
        LOG_LEVEL=${LOG_LEVEL_WARN}
        ;;

    SUCCESS)
        LOG_LEVEL=${LOG_LEVEL_SUCCESS}
        ;;

    INFO)
        LOG_LEVEL=${LOG_LEVEL_INFO}
        ;;

    DEBUG)
        LOG_LEVEL=${LOG_LEVEL_DEBUG}
        ;;

esac



#
# Проверка корректности уровня.
#
# При ошибочном значении используется INFO.
#

if ! [[ "${LOG_LEVEL}" =~ ^[0-3]$ ]]; then

    LOG_LEVEL=${LOG_LEVEL_INFO}

fi



#
# Цвета для консольного вывода.
#
# Если colors.sh уже загружен,
# используются его значения.
#
# Здесь только безопасный fallback.
#

: "${COLOR_RESET:=}"

: "${COLOR_RED:=}"

: "${COLOR_YELLOW:=}"

: "${COLOR_GREEN:=}"

: "${COLOR_BLUE:=}"

: "${COLOR_MAGENTA:=}"

: "${COLOR_CYAN:=}"



#
# Получение текущего времени.
#

_log_timestamp()
{
    date '+%Y-%m-%d %H:%M:%S'
}



#
# Преобразование имени уровня.
#

_log_level_name()
{
    local level="${1}"

    case "${level}" in

        0)
            echo "ERROR"
            ;;

        1)
            echo "WARN"
            ;;

        2)
            echo "INFO"
            ;;

        3)
            echo "DEBUG"
            ;;

        *)
            echo "INFO"
            ;;

    esac
}



#
# Выбор цвета сообщения.
#

_log_level_color()
{
    local label="${1}"

    case "${label}" in

        ERROR)
            printf "%s" "${COLOR_RED}"
            ;;

        FAIL)
            printf "%s" "${COLOR_RED}"
            ;;

        WARN)
            printf "%s" "${COLOR_YELLOW}"
            ;;

        SUCCESS)
            printf "%s" "${COLOR_GREEN}"
            ;;

        INFO)
            printf "%s" "${COLOR_BLUE}"
            ;;

        DEBUG)
            printf "%s" "${COLOR_MAGENTA}"
            ;;

        *)
            printf "%s" ""

    esac
}



#
# Внутренняя функция записи сообщения.
#
# Аргументы:
#
#   $1 уровень
#   $2 название уровня
#   $3 компонент
#   $4 сообщение
#

_log_write()
{
    local level="$1"
    local label="$2"
    local component="$3"
    local message="$4"


    #
    # Проверяем необходимость вывода.
    #

    if (( LOG_LEVEL < level )); then

        return 0

    fi



    local timestamp

    timestamp="$(_log_timestamp)"



    #
    # Цветной вывод в терминал.
    #

    local color

    color="$(_log_level_color "${label}")"



    local console_line

    console_line=$(printf "%b%s [%-7s] [%s]%b %s" \
        "${color}" \
        "${timestamp}" \
        "${label}" \
        "${component}" \
        "${COLOR_RESET}" \
        "${message}")



    if [[ "${label}" == "ERROR" || "${label}" == "FAIL" ]]; then

        printf "%s\n" "${console_line}" >&2

    else

        printf "%s\n" "${console_line}"

    fi



    #
    # Запись в файл.
    #
    # Ошибка журнала не должна останавливать LSM.
    #

    mkdir -p "${LSM_LOG_DIR}" 2>/dev/null || true


    printf "%s [%-7s] [%s] %s\n" \
        "${timestamp}" \
        "${label}" \
        "${component}" \
        "${message}" \
        >> "${LSM_LOG_FILE}" 2>/dev/null || true

}

# ==============================================================================
# Разбор аргументов публичных функций.
#
# Поддерживаемые варианты:
#
# Вариант 1:
#
#   log_info "Система запущена"
#
# Результат:
#
#   [INFO] [SYSTEM] Система запущена
#
#
# Вариант 2:
#
#   log_info "SMART" "Проверка диска"
#
# Результат:
#
#   [INFO] [SMART] Проверка диска
#
# ==============================================================================

_log_parse_args()
{
    local level="$1"
    local label="$2"

    shift 2


    local component="SYSTEM"
    local message=""


    #
    # Совместимость со старым API:
    #
    # log_info "MODULE" "Message"
    #

    if [[ $# -ge 2 ]]; then

        component="$1"

        shift

        message="$*"


    elif [[ $# -eq 1 ]]; then

        message="$1"

    fi



    _log_write \
        "${level}" \
        "${label}" \
        "${component}" \
        "${message}"
}



# ==============================================================================
# Публичный API LSM
# ==============================================================================


#
# ERROR
#
# Ошибка выполнения самого LSM.
#
# Пример:
#
#   Не найден конфигурационный файл
#

log_error()
{
    _log_parse_args \
        "${LOG_LEVEL_ERROR}" \
        "ERROR" \
        "$@"
}



#
# FAIL
#
# Проверка выполнена,
# но обнаружено плохое состояние системы.
#
# Пример:
#
#   RAID degraded
#   UPS отключен
#

log_fail()
{
    _log_parse_args \
        "${LOG_LEVEL_FAIL}" \
        "FAIL" \
        "$@"
}



#
# WARN
#
# Предупреждение.
#
# Пример:
#
#   Температура диска 48°C
#

log_warn()
{
    _log_parse_args \
        "${LOG_LEVEL_WARN}" \
        "WARN" \
        "$@"
}



#
# SUCCESS
#
# Успешное выполнение операции.
#

log_success()
{
    _log_parse_args \
        "${LOG_LEVEL_SUCCESS}" \
        "SUCCESS" \
        "$@"
}



#
# INFO
#
# Обычная информация.
#

log_info()
{
    _log_parse_args \
        "${LOG_LEVEL_INFO}" \
        "INFO" \
        "$@"
}



#
# DEBUG
#
# Отладочная информация.
#

log_debug()
{
    _log_parse_args \
        "${LOG_LEVEL_DEBUG}" \
        "DEBUG" \
        "$@"
}
