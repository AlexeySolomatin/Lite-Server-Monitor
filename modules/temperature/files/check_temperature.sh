#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Модуль мониторинга температуры компонентов
#
# Путь:
#   modules/temperature/files/check_temperature.sh
#
# Назначение:
#   Проверка температур CPU и других компонентов системы.
#
#   Источники данных:
#
#       1. утилита sensors (пакет lm-sensors);
#       2. фолбэк — /sys/class/thermal/thermal_zone*/temp,
#          если lm-sensors не установлен или не вернул данных.
#
# Режимы:
#
#   check_temperature.sh status
#       Краткий текущий статус. Всегда возвращает exit 0.
#
#   check_temperature.sh report
#       Подробный отчет по всем датчикам. Всегда возвращает exit 0.
#
#   check_temperature.sh check
#       Машинная проверка с уведомлениями.
#       Коды выхода: 0 = OK, 1 = WARNING, 2 = CRITICAL/ошибка окружения.
#
# ==============================================================================


set -Eeuo pipefail


#
# Сброс локали для предсказуемого парсинга вывода sensors
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

CONFIG_FILE="/etc/lsm/modules/temperature.conf"

if [[ -f "${CONFIG_FILE}" ]]; then

    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"

fi


#
# Значения по умолчанию
#

WARNING_TEMP="${WARNING_TEMP:-70}"

CRITICAL_TEMP="${CRITICAL_TEMP:-80}"

NOTIFY_ON_WARNING="${NOTIFY_ON_WARNING:-true}"

NOTIFY_ON_RECOVERY="${NOTIFY_ON_RECOVERY:-true}"


#
# Состояние / блокировка
#

STATE_DIR="/var/lib/lsm/state"

STATE_FILE="${STATE_DIR}/temperature_alert"

LOCK_FILE="${STATE_DIR}/temperature_check.lock"


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
# Сбор показаний датчиков
# ==============================================================================

#
# Результат — глобальные переменные:
#
#   SENSOR_NAMES[]  имена датчиков;
#   SENSOR_VALUES[] значения в целых градусах Цельсия;
#   HIGHEST_TEMP    максимальное значение (0 — данных нет).
#

temperature_collect()
{
    SENSOR_NAMES=()

    SENSOR_VALUES=()

    HIGHEST_TEMP=0


    local line
    local name
    local tpart
    local raw
    local value


    #
    # 1. Попытка получить температуры через утилиту 'sensors'
    #

    if command -v sensors >/dev/null 2>&1; then

        TEMP_DATA="$(sensors 2>/dev/null || true)"


        #
        # Температуры дисков (чипы drivetemp) — зона ответственности
        # модуля smart. Здесь они исключаются, чтобы одна метрика
        # не приходила из двух модулей.
        #

        chip_skip=false


        while IFS= read -r line; do

            if [[ "${line}" != *:* ]]; then

                #
                # Строка-заголовок чипа: переключаем контекст.
                #

                if [[ "${line}" =~ ^drivetemp ]]; then

                    chip_skip=true

                elif [[ "${line}" =~ ^[A-Za-z0-9_-]+$ ]]; then

                    chip_skip=false

                fi

                continue

            fi

            [[ "${chip_skip}" == true ]] && continue

            name="${line%%:*}"

            tpart="${line#*:}"


            #
            # Строки без имени или без значения температуры пропускаем
            #

            [[ -z "${name}" ]] && continue

            raw="$(printf '%s' "${tpart}" | grep -oE '\+[0-9]+(\.[0-9]+)?°C' | head -n 1 || true)"

            [[ -z "${raw}" ]] && continue


            value="$(printf '%s' "${raw}" | tr -d '+°C')"

            [[ "${value}" =~ ^[0-9]+([.][0-9]+)?$ ]] || continue

            value="$(printf '%s' "${value}" | awk '{print int($1)}')"


            SENSOR_NAMES+=("${name}")

            SENSOR_VALUES+=("${value}")

            if (( value > HIGHEST_TEMP )); then

                HIGHEST_TEMP="${value}"

            fi

        done <<< "${TEMP_DATA}"

    fi


    #
    # 2. Фолбэк на sysfs (/sys/class/thermal/),
    #    если sensors недоступен или не вернул данных
    #

    if (( HIGHEST_TEMP == 0 )) &&
       compgen -G "/sys/class/thermal/thermal_zone*/temp" > /dev/null; then

        local zone
        local zone_name
        local raw_temp
        local temp_c

        for zone in /sys/class/thermal/thermal_zone*; do

            [[ -r "${zone}/temp" ]] || continue

            raw_temp="$(cat "${zone}/temp" 2>/dev/null || echo 0)"

            [[ "${raw_temp}" =~ ^[0-9]+$ ]] || continue

            (( raw_temp > 0 )) || continue

            temp_c=$(( raw_temp / 1000 ))

            zone_name="$(cat "${zone}/type" 2>/dev/null || basename "${zone}")"


            SENSOR_NAMES+=("${zone_name}")

            SENSOR_VALUES+=("${temp_c}")

            if (( temp_c > HIGHEST_TEMP )); then

                HIGHEST_TEMP="${temp_c}"

            fi

        done

    fi


    return 0
}


#
# Сводный статус по максимальной температуре.
#

temperature_overall()
{
    if (( HIGHEST_TEMP == 0 )); then

        printf '%s' "НЕИЗВЕСТНО"

    elif (( HIGHEST_TEMP >= CRITICAL_TEMP )); then

        printf '%s' "CRITICAL"

    elif (( HIGHEST_TEMP >= WARNING_TEMP )); then

        printf '%s' "WARNING"

    else

        printf '%s' "OK"

    fi
}


# ==============================================================================
# Краткий статус
# ==============================================================================

do_status()
{
    temperature_collect


    if (( ${#SENSOR_NAMES[@]} == 0 )); then

        printf 'Температура: датчики не обнаружены\n'

        return 0

    fi


    printf 'Максимальная температура: %s°C\n' "${HIGHEST_TEMP}"

    printf 'Датчиков: %d\n' "${#SENSOR_NAMES[@]}"

    printf 'Статус: %s\n' "$(temperature_overall)"


    return 0
}


# ==============================================================================
# Подробный отчет
# ==============================================================================

do_report()
{
    temperature_collect


    printf '================================================================\n'

    printf 'Отчет по температурам\n'

    printf '================================================================\n'


    if (( ${#SENSOR_NAMES[@]} == 0 )); then

        printf '\nДатчики температуры не обнаружены.\n'

        printf 'Установите lm-sensors или проверьте /sys/class/thermal/.\n\n'

        return 0

    fi


    printf '\nПороги: WARNING %s°C / CRITICAL %s°C\n' \
        "${WARNING_TEMP}" \
        "${CRITICAL_TEMP}"


    printf '\n%-36s %12s\n' \
        "Датчик" \
        "Значение"

    printf '%s\n' \
        "------------------------------------------------------------"


    local i

    for i in "${!SENSOR_NAMES[@]}"; do

        printf '%-36s %11s°C\n' \
            "${SENSOR_NAMES[$i]}" \
            "${SENSOR_VALUES[$i]}"

    done


    printf '\nМаксимальная температура: %s°C\n' "${HIGHEST_TEMP}"

    printf 'Общий статус: %s\n' "$(temperature_overall)"

    printf '\n'


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

        log_info "TEMPERATURE" "Пропуск: предыдущая проверка выполняется."

        exit 0

    fi


    temperature_collect


    #
    # Если температуру извлечь не удалось — завершаем без ошибок.
    #

    if (( ${#SENSOR_NAMES[@]} == 0 )); then

        log_info "TEMPERATURE" "Пропуск проверки: датчики температуры не найдены."

        return 0

    fi


    local prev_state=""

    if [[ -f "${STATE_FILE}" ]]; then

        prev_state="$(cat "${STATE_FILE}" 2>/dev/null || true)"

    fi


    #
    # Проверка пороговых значений
    #

    if (( HIGHEST_TEMP >= CRITICAL_TEMP )); then


        #
        # Критический перегрев
        #

        if [[ "${prev_state}" != "CRITICAL" ]]; then

            echo "CRITICAL" > "${STATE_FILE}"

            log_error "TEMPERATURE" "Критическая температура: ${HIGHEST_TEMP}°C (порог: ${CRITICAL_TEMP}°C)."

            if declare -F notify >/dev/null 2>&1; then

                notify "temperature" "CRITICAL" \
                    "🔥 Критическая температура процессора/системы: ${HIGHEST_TEMP}°C (порог: ${CRITICAL_TEMP}°C)"

            fi

        fi


    elif (( HIGHEST_TEMP >= WARNING_TEMP )); then


        #
        # Предупредительный перегрев
        #

        if [[ "${prev_state}" != "WARNING" && "${prev_state}" != "CRITICAL" ]]; then

            echo "WARNING" > "${STATE_FILE}"

            log_warn "TEMPERATURE" "Высокая температура: ${HIGHEST_TEMP}°C (порог: ${WARNING_TEMP}°C)."


            if [[ "${NOTIFY_ON_WARNING}" == "true" ]] &&
               declare -F notify >/dev/null 2>&1; then

                notify "temperature" "WARNING" \
                    "⚠️ Высокая температура процессора/системы: ${HIGHEST_TEMP}°C (порог: ${WARNING_TEMP}°C)"

            fi

        fi


    else


        #
        # Нормализация температуры
        #

        if [[ -n "${prev_state}" ]]; then

            rm -f "${STATE_FILE}"

            log_success "TEMPERATURE" "Температура нормализовалась: ${HIGHEST_TEMP}°C."


            if [[ "${NOTIFY_ON_RECOVERY}" == "true" ]] &&
               declare -F notify >/dev/null 2>&1; then

                notify "temperature" "OK" \
                    "✅ Температура процессора/системы нормализовалась: ${HIGHEST_TEMP}°C"

            fi

        fi

    fi


    #
    # Module API: ненулевой код означает проблемное состояние.
    #

    case "$(temperature_overall)" in

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
