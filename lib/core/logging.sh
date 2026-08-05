```bash
#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Библиотека централизованного логирования
#
# Путь:
#   lib/core/logging.sh
#
# Назначение:
#   Единый механизм регистрации событий и результатов проверок LSM.
#
# Поддерживаемые уровни:
#
#   ERROR   - ошибка выполнения самого LSM
#   FAIL    - проверка выполнена, состояние системы неудовлетворительное
#   WARN    - предупреждение, состояние требует внимания
#   SUCCESS - успешное выполнение операции / проверки
#   INFO    - информационное сообщение
#   DEBUG   - отладочная информация
#
# Примеры:
#
#   log_info "Запуск проверки системы"
#
#   log_success "RAID" "RAID1 массив активен"
#
#   log_warn "SMART" "Температура диска 48°C"
#
#   log_fail "UPS" "ИБП отключен"
#
# Формат консоли:
#
#   2026-08-05 09:40:12 [SUCCESS] [RAID] RAID1 массив активен
#   2026-08-05 09:40:13 [WARN   ] [SMART] Температура диска 48°C
#   2026-08-05 09:40:14 [FAIL   ] [UPS] ИБП отключен
#
# Формат файла журнала:
#
#   2026-08-05 09:40:12 [SUCCESS] [RAID] RAID1 массив активен
#
# Архитектурный принцип:
#
#   logging.sh отвечает только за регистрацию и вывод событий.
#
#   ui.sh отвечает за оформление интерфейса:
#       баннеры, заголовки, секции.
#
#   colors.sh отвечает за ANSI-цвета.
#
#   Модули не должны самостоятельно определять ANSI-коды
#   или реализовывать собственный формат логирования.
#
# ==============================================================================


set -Eeuo pipefail



#
# Защита от повторной загрузки библиотеки.
#

[[ -n "${LSM_LOGGING_LOADED:-}" ]] && return 0

readonly LSM_LOGGING_LOADED=1



#
# Определение корня LSM.
#
# Используется только если LSM_ROOT еще не установлен.
#

LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

export LSM_ROOT



#
# Подключение централизованной библиотеки цветов.
#
# logging.sh не должен самостоятельно определять ANSI-коды.
#

if [[ -f "${LSM_ROOT}/lib/core/colors.sh" ]]; then

    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/core/colors.sh"

fi



#
# Безопасный fallback.
#
# Он нужен только в случае, если colors.sh недоступен.
#
# В штатной установке LSM эти значения предоставляет colors.sh.
#

: "${COLOR_RESET:=}"
: "${COLOR_BOLD:=}"

: "${COLOR_RED:=}"
: "${COLOR_GREEN:=}"
: "${COLOR_YELLOW:=}"
: "${COLOR_BLUE:=}"
: "${COLOR_MAGENTA:=}"
: "${COLOR_CYAN:=}"
: "${COLOR_WHITE:=}"



#
# Настройки логирования по умолчанию.
#
# Можно переопределить до подключения библиотеки:
#
#   LOG_LEVEL=3
#   LSM_LOG_DIR=/custom/path
#   LSM_LOG_FILE=/custom/path/lsm.log
#

: "${LOG_LEVEL:=2}"

: "${LSM_LOG_DIR:=/var/log/lsm}"

: "${LSM_LOG_FILE:=${LSM_LOG_DIR}/lsm.log}"



#
# Числовые уровни логирования.
#
# Чем меньше число, тем выше приоритет.
#
#   0 ERROR
#   1 FAIL / WARN
#   2 SUCCESS / INFO
#   3 DEBUG
#
# Это означает:
#
#   LOG_LEVEL=0 -> только ERROR
#   LOG_LEVEL=1 -> ERROR, FAIL, WARN
#   LOG_LEVEL=2 -> ERROR, FAIL, WARN, SUCCESS, INFO
#   LOG_LEVEL=3 -> все сообщения
#

readonly LOG_LEVEL_ERROR=0
readonly LOG_LEVEL_FAIL=1
readonly LOG_LEVEL_WARN=1
readonly LOG_LEVEL_SUCCESS=2
readonly LOG_LEVEL_INFO=2
readonly LOG_LEVEL_DEBUG=3



#
# Нормализация LOG_LEVEL.
#
# Поддерживаются:
#
#   0-3
#   ERROR
#   FAIL
#   WARN
#   WARNING
#   SUCCESS
#   INFO
#   DEBUG
#

case "${LOG_LEVEL^^}" in

    ERROR)

        LOG_LEVEL="${LOG_LEVEL_ERROR}"

        ;;


    FAIL)

        LOG_LEVEL="${LOG_LEVEL_FAIL}"

        ;;


    WARN|WARNING)

        LOG_LEVEL="${LOG_LEVEL_WARN}"

        ;;


    SUCCESS)

        LOG_LEVEL="${LOG_LEVEL_SUCCESS}"

        ;;


    INFO)

        LOG_LEVEL="${LOG_LEVEL_INFO}"

        ;;


    DEBUG)

        LOG_LEVEL="${LOG_LEVEL_DEBUG}"

        ;;

esac



#
# Проверка корректности уровня.
#
# При неизвестном значении используется INFO.
#

if ! [[ "${LOG_LEVEL}" =~ ^[0-3]$ ]]; then

    LOG_LEVEL="${LOG_LEVEL_INFO}"

fi



#
# Время события.
#
# Формат:
#
#   YYYY-MM-DD HH:MM:SS
#

_log_timestamp()
{

    date '+%Y-%m-%d %H:%M:%S'

}



#
# Выбор цвета по уровню сообщения.
#
# Цвета предоставляются colors.sh.
#

_log_level_color()
{

    local label="${1:-}"



    case "${label}" in

        ERROR|FAIL)

            printf '%s' "${COLOR_RED}"

            ;;


        WARN)

            printf '%s' "${COLOR_YELLOW}"

            ;;


        SUCCESS)

            printf '%s' "${COLOR_GREEN}"

            ;;


        INFO)

            printf '%s' "${COLOR_BLUE}"

            ;;


        DEBUG)

            printf '%s' "${COLOR_MAGENTA}"

            ;;


        *)

            printf '%s' ""

            ;;

    esac

}



#
# Внутренняя запись сообщения.
#
# Аргументы:
#
#   $1 - числовой уровень
#   $2 - текстовый уровень
#   $3 - компонент
#   $4 - сообщение
#

_log_write()
{

    local level="$1"
    local label="$2"
    local component="$3"
    local message="$4"



    #
    # Проверка уровня фильтрации.
    #
    # Например:
    #
    #   LOG_LEVEL=2
    #
    # Показываются:
    #
    #   ERROR
    #   FAIL
    #   WARN
    #   SUCCESS
    #   INFO
    #
    # DEBUG скрывается.
    #

    if (( LOG_LEVEL < level )); then

        return 0

    fi



    local timestamp

    timestamp="$(_log_timestamp)"



    #
    # Получение цвета.
    #

    local color

    color="$(_log_level_color "${label}")"



    #
    # Формирование строки консольного вывода.
    #
    # printf используется вместо echo -e.
    #

    local console_line

    console_line="$(
        printf '%b%s [%-7s] [%s]%b %s' \
            "${color}" \
            "${timestamp}" \
            "${label}" \
            "${component}" \
            "${COLOR_RESET}" \
            "${message}"
    )"



    #
    # ERROR и FAIL являются ошибочными состояниями
    # и выводятся в stderr.
    #
    # Остальные сообщения выводятся в stdout.
    #

    case "${label}" in

        ERROR|FAIL)

            printf '%s\n' "${console_line}" >&2

            ;;


        *)

            printf '%s\n' "${console_line}"

            ;;

    esac



    #
    # Запись в файл.
    #
    # Отказ файлового журнала не должен останавливать LSM.
    #

    if mkdir -p "${LSM_LOG_DIR}" 2>/dev/null; then

        printf '%s [%-7s] [%s] %s\n' \
            "${timestamp}" \
            "${label}" \
            "${component}" \
            "${message}" \
            >> "${LSM_LOG_FILE}" 2>/dev/null || true

    fi

}



#
# Разбор аргументов публичного API.
#
# Поддерживаются два варианта:
#
#   log_info "Система запущена"
#
# Результат:
#
#   [INFO] [SYSTEM] Система запущена
#
#
#   log_info "SMART" "Проверка диска"
#
# Результат:
#
#   [INFO] [SMART] Проверка диска
#
#
# Дополнительные аргументы сообщения объединяются через пробел.
#

_log_parse_args()
{

    local level="$1"
    local label="$2"

    shift 2



    local component="SYSTEM"
    local message=""



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
# Ошибка самого LSM:
#
#   - отсутствует конфигурация;
#   - невозможно выполнить внутреннюю операцию;
#   - отсутствует необходимая библиотека.
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
# Проверка выполнена успешно с технической точки зрения,
# но состояние проверяемого объекта неудовлетворительное.
#
# Примеры:
#
#   RAID degraded
#   UPS отключен
#   SMART ошибка
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
# Состояние не является критической ошибкой,
# но требует внимания.
#
# Примеры:
#
#   Температура 48°C
#   Диск заполнен на 85%
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
# Проверка или операция завершена успешно.
#
# Примеры:
#
#   RAID1 массив активен
#   SMART проверка пройдена
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
# Информационное сообщение,
# не являющееся результатом проверки.
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
# Показывается только при LOG_LEVEL=3.
#

log_debug()
{

    _log_parse_args \
        "${LOG_LEVEL_DEBUG}" \
        "DEBUG" \
        "$@"

}
```
