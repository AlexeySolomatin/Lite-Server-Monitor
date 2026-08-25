#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Модуль мониторинга системных ресурсов
#
# Путь:
#   modules/system/files/check_system.sh
#
# Назначение:
#   Проверка загрузки CPU (load average), использования памяти
#   и заполнения корневой файловой системы.
#
# Режимы:
#
#   check_system.sh status
#       Краткий текущий статус. Всегда возвращает exit 0.
#
#   check_system.sh report
#       Подробный отчет по всем метрикам. Всегда возвращает exit 0.
#
#   check_system.sh check
#       Машинная проверка с уведомлениями и записью состояния.
#       Коды выхода: 0 = OK, 1 = WARNING, 2 = CRITICAL/ошибка окружения.
#
# ==============================================================================


set -Eeuo pipefail


#
# Сброс локали для стандартизации вывода системных команд
#

export LC_ALL=C

export LANG=C


#
# Каталоги проекта
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"


#
# Конфигурация модуля
#

CONFIG_FILE="/etc/lsm/modules/system.conf"

if [[ -f "${CONFIG_FILE}" ]]; then

    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"

fi


#
# Значения по умолчанию
#

LOAD_WARNING="${LOAD_WARNING:-5.0}"

LOAD_CRITICAL="${LOAD_CRITICAL:-10.0}"

MEMORY_WARNING="${MEMORY_WARNING:-85}"

MEMORY_CRITICAL="${MEMORY_CRITICAL:-95}"

DISK_WARNING="${DISK_WARNING:-85}"

DISK_CRITICAL="${DISK_CRITICAL:-95}"

NOTIFY_ON_WARNING="${NOTIFY_ON_WARNING:-true}"

NOTIFY_ON_RECOVERY="${NOTIFY_ON_RECOVERY:-true}"


#
# Состояние / блокировка
#

STATE_DIR="/var/lib/lsm/state"

STATUS_FILE="${STATE_DIR}/system.status"

LOCK_FILE="${STATE_DIR}/system_check.lock"


#
# Библиотеки ядра и система уведомлений
#

if [[ -f "${PROJECT_ROOT}/lib/core/common.sh" ]]; then

    # shellcheck source=/dev/null
    source "${PROJECT_ROOT}/lib/core/common.sh"

fi

if [[ -f "${PROJECT_ROOT}/lib/core/logging.sh" ]]; then

    # shellcheck source=/dev/null
    source "${PROJECT_ROOT}/lib/core/logging.sh"

fi

if [[ -f "${PROJECT_ROOT}/lib/notifications/notify.sh" ]]; then

    # shellcheck source=/dev/null
    source "${PROJECT_ROOT}/lib/notifications/notify.sh"

fi


#
# Резервные функции журналирования на случай,
# если библиотеки ядра недоступны
#

if ! declare -F log_info >/dev/null 2>&1; then
    log_info() { printf '%s\n' "$*"; }
fi

if ! declare -F log_warn >/dev/null 2>&1; then
    log_warn() { printf '%s\n' "$*" >&2; }
fi

if ! declare -F log_error >/dev/null 2>&1; then
    log_error() { printf '%s\n' "$*" >&2; }
fi

if ! declare -F log_success >/dev/null 2>&1; then
    log_success() { printf '%s\n' "$*"; }
fi


#
# Режим работы
#

MODE="${1:-check}"


# ==============================================================================
# Сбор метрик и определение общего состояния
# ==============================================================================

#
# Результат — глобальные переменные:
#
#   STATUS         OK | WARNING | CRITICAL
#   ALERT_MESSAGES массив текстов проблем
#   LOAD           загрузка CPU (1 мин) или "н/д"
#   MEMORY_USED    процент использования памяти или "н/д"
#   DISK_USED      процент использования корневой ФС или "н/д"
#

system_collect()
{
    STATUS="OK"

    ALERT_MESSAGES=()


    #
    # 1. Проверка CPU Load
    #

    if [[ -f /proc/loadavg ]]; then

        LOAD=$(awk '{print $1}' /proc/loadavg)


        #
        # Масштабируем float в int (умножаем на 10)
        # для точного сравнения в Bash
        #

        LOAD_SCALE=$(awk -v l="${LOAD}" 'BEGIN {printf "%.0f", l * 10}')

        LOAD_WARN_SCALE=$(awk -v w="${LOAD_WARNING}" 'BEGIN {printf "%.0f", w * 10}')

        LOAD_CRIT_SCALE=$(awk -v c="${LOAD_CRITICAL}" 'BEGIN {printf "%.0f", c * 10}')


        if (( LOAD_SCALE >= LOAD_CRIT_SCALE )); then

            STATUS="CRITICAL"

            ALERT_MESSAGES+=("Загрузка CPU критическая: ${LOAD} (порог: ${LOAD_CRITICAL})")

        elif (( LOAD_SCALE >= LOAD_WARN_SCALE )); then

            if [[ "${STATUS}" != "CRITICAL" ]]; then

                STATUS="WARNING"

            fi

            ALERT_MESSAGES+=("Загрузка CPU высокая: ${LOAD} (порог: ${LOAD_WARNING})")

        fi

    else

        LOAD="н/д"

    fi


    #
    # 2. Проверка RAM (через /proc/meminfo)
    #

    if [[ -f /proc/meminfo ]]; then

        MEM_TOTAL=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)

        MEM_AVAIL=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)


        #
        # Fallback для старых ядер без MemAvailable
        #

        if [[ -z "${MEM_AVAIL}" ]]; then

            MEM_AVAIL=$(awk '/MemFree:/ {print $2}' /proc/meminfo || true)

        fi

        MEM_AVAIL="${MEM_AVAIL:-0}"


        if [[ -n "${MEM_TOTAL}" && "${MEM_TOTAL}" -gt 0 ]]; then

            MEM_USED_KB=$(( MEM_TOTAL - MEM_AVAIL ))

            MEMORY_USED=$(( MEM_USED_KB * 100 / MEM_TOTAL ))


            if (( MEMORY_USED >= MEMORY_CRITICAL )); then

                STATUS="CRITICAL"

                ALERT_MESSAGES+=("Использование памяти критическое: ${MEMORY_USED}% (порог: ${MEMORY_CRITICAL}%)")

            elif (( MEMORY_USED >= MEMORY_WARNING )); then

                if [[ "${STATUS}" != "CRITICAL" ]]; then

                    STATUS="WARNING"

                fi

                ALERT_MESSAGES+=("Использование памяти высокое: ${MEMORY_USED}% (порог: ${MEMORY_WARNING}%)")

            fi

        else

            MEMORY_USED="н/д"

        fi

    else

        MEMORY_USED="н/д"

    fi


    #
    # 3. Проверка корневого раздела /
    #

    if command -v df >/dev/null 2>&1; then

        DISK_USED=$(df -P / | awk 'NR==2 {print $5}' | tr -d '%')


        if [[ -n "${DISK_USED}" ]]; then

            if (( DISK_USED >= DISK_CRITICAL )); then

                STATUS="CRITICAL"

                ALERT_MESSAGES+=("Корневая ФС / заполнена критически: ${DISK_USED}% (порог: ${DISK_CRITICAL}%)")

            elif (( DISK_USED >= DISK_WARNING )); then

                if [[ "${STATUS}" != "CRITICAL" ]]; then

                    STATUS="WARNING"

                fi

                ALERT_MESSAGES+=("Корневая ФС / заполнена сильно: ${DISK_USED}% (порог: ${DISK_WARNING}%)")

            fi

        else

            DISK_USED="н/д"

        fi

    else

        DISK_USED="н/д"

    fi


    return 0
}


#
# Текст списка проблем (пустая строка, если проблем нет).
#

system_build_details()
{
    local message

    if (( ${#ALERT_MESSAGES[@]} == 0 )); then

        return 0

    fi


    for message in "${ALERT_MESSAGES[@]}"; do

        printf -- '- %s\n' "${message}"

    done
}


# ==============================================================================
# Краткий статус
# ==============================================================================

do_status()
{
    system_collect


    printf 'Система:\n'

    printf '  Загрузка CPU : %s\n' "${LOAD}"

    printf '  Память       : %s\n' "${MEMORY_USED}"

    printf '  Корневая ФС  : %s\n' "${DISK_USED}"

    printf 'Итого: %s\n' "${STATUS}"


    #
    # Статус — информационный режим, всегда успешный код выхода.
    #

    return 0
}


# ==============================================================================
# Подробный отчет
# ==============================================================================

do_report()
{
    system_collect


    printf '================================================================\n'

    printf 'Отчет о состоянии системы\n'

    printf '================================================================\n'

    printf '\nЗагрузка CPU (1 мин) : %s\n' "${LOAD}"

    printf 'Память               : %s\n' "${MEMORY_USED}"

    printf 'Корневая ФС /        : %s\n' "${DISK_USED}"


    printf '\nПороги:\n'

    printf '  CPU Load           : WARNING %s / CRITICAL %s\n' "${LOAD_WARNING}" "${LOAD_CRITICAL}"

    printf '  Память             : WARNING %s%% / CRITICAL %s%%\n' "${MEMORY_WARNING}" "${MEMORY_CRITICAL}"

    printf '  Корневая ФС /      : WARNING %s%% / CRITICAL %s%%\n' "${DISK_WARNING}" "${DISK_CRITICAL}"


    printf '\nОбщий статус: %s\n' "${STATUS}"


    local details

    details="$(system_build_details)"

    if [[ -n "${details}" ]]; then

        printf '\nОбнаруженные проблемы:\n%s\n' "${details}"

    else

        printf '\nВсе системные метрики в пределах нормы.\n'

    fi


    #
    # Отчет не отправляет уведомления и всегда успешен.
    #

    return 0
}


# ==============================================================================
# Машинная проверка с уведомлениями
# ==============================================================================

do_check()
{
    #
    # Каталог состояния должен существовать ДО захвата блокировки.
    #

    mkdir -p "${STATE_DIR}"


    #
    # Защита от параллельного запуска.
    #

    exec 200>"${LOCK_FILE}"

    if ! flock -n 200; then

        log_info "SYSTEM" "Пропуск: предыдущая проверка выполняется."

        exit 0

    fi


    system_collect


    #
    # Сохранение локального отчета о состоянии
    #

    cat > "${STATUS_FILE}" <<EOF
STATUS=${STATUS}
LOAD=${LOAD}
MEMORY=${MEMORY_USED}
DISK=${DISK_USED}
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
EOF


    #
    # Отправка уведомления через центральный диспетчер
    #

    if declare -F notify >/dev/null 2>&1; then

        local details
        local full_msg

        details="$(system_build_details)"

        full_msg=""


        case "${STATUS}" in

            CRITICAL)

                printf -v full_msg "Критические проблемы системных ресурсов:\n%s" \
                    "${details}"

                notify "system" "CRITICAL" "${full_msg}"

                ;;

            WARNING)

                if [[ "${NOTIFY_ON_WARNING}" == "true" ]]; then

                    printf -v full_msg "Обнаружены проблемы системных ресурсов:\n%s" \
                        "${details}"

                    notify "system" "WARNING" "${full_msg}"

                fi

                ;;

            OK)

                if [[ "${NOTIFY_ON_RECOVERY}" == "true" ]]; then

                    notify "system" "OK" \
                        "Все системные метрики (CPU, память, корневая ФС) вернулись в норму."

                fi

                ;;

        esac

    fi


    #
    # Module API: ненулевой код означает проблемное состояние.
    #

    case "${STATUS}" in

        OK)

            return 0

            ;;

        WARNING)

            return 1

            ;;

        *)

            return 2

            ;;

    esac
}


# ==============================================================================
# Диспетчер режимов Module API
# ==============================================================================

main()
{
    case "${MODE}" in

        status)

            do_status

            ;;

        report)

            do_report

            ;;

        check)

            do_check

            ;;

        *)

            printf 'Неизвестный режим: %s\n' "${MODE}" >&2
            printf 'Использование: %s {status|report|check}\n' "$0" >&2

            return 2

            ;;

    esac
}


main "$@"
