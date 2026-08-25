#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Модуль проверки состояния ИБП через apcupsd
#
# Путь:
#   modules/ups/files/check_ups.sh
#
# Назначение:
#   Мониторинг ИБП через демон apcupsd: работа от сети или от батареи,
#   уровень заряда и остаток времени автономной работы.
#
# Режимы:
#
#   check_ups.sh status
#       Краткий текущий статус. Всегда возвращает exit 0.
#
#   check_ups.sh report
#       Подробный отчет по параметрам ИБП. Всегда возвращает exit 0.
#
#   check_ups.sh check
#       Машинная проверка с уведомлениями и фиксацией состояний.
#       Коды выхода: 0 = OK, 1 = WARNING, 2 = CRITICAL/ошибка окружения.
#
# ==============================================================================


set -Eeuo pipefail


#
# Сброс локали для предсказуемого парсинга вывода apcaccess
#

export LC_ALL=C

export LANG=C


#
# Каталоги проекта
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"


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
# Конфигурация модуля
#

CONFIG_FILE="/etc/lsm/modules/ups.conf"

if [[ -f "${CONFIG_FILE}" ]]; then

    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"

fi


#
# Значения по умолчанию с поддержкой обоих вариантов наименования
#

BATTERY_WARNING="${BATTERY_WARNING:-${UPS_BATTERY_WARN_THRESHOLD:-50}}"

BATTERY_CRITICAL="${BATTERY_CRITICAL:-${UPS_BATTERY_CRIT_THRESHOLD:-20}}"

RUNTIME_WARNING="${RUNTIME_WARNING:-10}"

NOTIFY_ON_BATTERY="${NOTIFY_ON_BATTERY:-true}"

NOTIFY_ON_LOW_BATTERY="${NOTIFY_ON_LOW_BATTERY:-true}"

NOTIFY_ON_RECOVERY="${NOTIFY_ON_RECOVERY:-true}"


#
# Состояние / блокировка
#

STATE_DIR="/var/lib/lsm/state"

STATE_FILE="${STATE_DIR}/ups_state"

LOCK_FILE="${STATE_DIR}/ups_check.lock"

APCACCESS_BIN="${APCACCESS_BIN:-apcaccess}"


#
# Режим работы
#

MODE="${1:-check}"


# ==============================================================================
# Вспомогательные функции
# ==============================================================================

#
# Опрос демона apcupsd.
#

ups_query()
{
    "${APCACCESS_BIN}" status 2>/dev/null || true
}


#
# Разбор вывода apcaccess.
#
# Результат — глобальные переменные:
#
#   STATUS_RAW   строка состояния ("ONLINE", "ONBATT ..." и т.п.);
#   CHARGE_RAW   заряд как в выводе ("100.0 Percent");
#   CHARGE_INT   заряд целым числом процентов;
#   TIMELEFT_RAW остаток времени как в выводе ("9.9 Minutes");
#   TIMELEFT_MIN остаток времени в минутах (float) либо пусто.
#

ups_parse()
{
    STATUS_RAW="$(printf '%s\n' "${UPS_STATUS}" | awk -F': ' '/STATUS/ {print $2}' | xargs || true)"

    CHARGE_RAW="$(printf '%s\n' "${UPS_STATUS}" | awk -F': ' '/BCHARGE/ {print $2}' | awk '{print $1}' || true)"

    TIMELEFT_RAW="$(printf '%s\n' "${UPS_STATUS}" | awk -F': ' '/TIMELEFT/ {print $2}' | xargs || true)"

    CHARGE_INT=100

    if [[ -n "${CHARGE_RAW}" ]]; then

        CHARGE_INT="${CHARGE_RAW%.*}"

    fi

    #
    # Валидация числа перед арифметическими операциями
    #

    if [[ ! "${CHARGE_INT}" =~ ^[0-9]+$ ]]; then

        CHARGE_INT=100

    fi


    #
    # Остаток времени приводится к минутам
    #

    TIMELEFT_MIN=""

    if [[ -n "${TIMELEFT_RAW}" ]]; then

        local tl_value="${TIMELEFT_RAW%% *}"

        local tl_unit="${TIMELEFT_RAW##* }"

        if [[ "${tl_value}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then

            case "${tl_unit}" in

                Seconds|SECONDS)

                    TIMELEFT_MIN="$(awk -v v="${tl_value}" 'BEGIN {printf "%.1f", v / 60}')"

                    ;;

                Hours|HOURS)

                    TIMELEFT_MIN="$(awk -v v="${tl_value}" 'BEGIN {printf "%.1f", v * 60}')"

                    ;;

                *)

                    #
                    # Minutes и значения без единиц измерения
                    #

                    TIMELEFT_MIN="${tl_value}"

                    ;;

            esac

        fi

    fi

    return 0
}


#
# Сводное состояние ИБП по разобранным данным.
#

ups_current_state()
{
    local state="ONLINE"

    if [[ "${STATUS_RAW}" != *"ONLINE"* ]]; then

        if (( CHARGE_INT <= BATTERY_CRITICAL )); then

            state="CRITICAL"

        elif (( CHARGE_INT <= BATTERY_WARNING )); then

            state="WARNING"

        else

            state="ON_BATTERY"

        fi

    elif [[ -n "${TIMELEFT_MIN}" ]] &&
         [[ "$(awk -v t="${TIMELEFT_MIN}" -v r="${RUNTIME_WARNING}" 'BEGIN {print (t < r) ? 1 : 0}')" == "1" ]]; then

        #
        # Работа от сети, но запас времени ниже порога RUNTIME_WARNING
        #

        state="LOW_RUNTIME"

    fi

    printf '%s' "${state}"
}


# ==============================================================================
# Краткий статус
# ==============================================================================

do_status()
{
    if ! command -v "${APCACCESS_BIN}" >/dev/null 2>&1; then

        printf 'ИБП: недоступно (утилита %s не найдена)\n' "${APCACCESS_BIN}"

        return 0

    fi


    UPS_STATUS="$(ups_query)"

    if [[ -z "${UPS_STATUS}" ]]; then

        printf 'ИБП: apcupsd не отвечает на запрос статуса\n'

        return 0

    fi


    ups_parse


    printf 'Статус ИБП      : %s\n' "${STATUS_RAW:-неизвестно}"

    printf 'Заряд батареи   : %s\n' "${CHARGE_RAW:-н/д}"

    printf 'Осталось времени: %s\n' "${TIMELEFT_RAW:-н/д}"


    return 0
}


# ==============================================================================
# Подробный отчет
# ==============================================================================

do_report()
{
    if ! command -v "${APCACCESS_BIN}" >/dev/null 2>&1; then

        printf 'Отчет по ИБП: недоступно (утилита %s не найдена)\n' "${APCACCESS_BIN}"

        return 0

    fi


    UPS_STATUS="$(ups_query)"

    if [[ -z "${UPS_STATUS}" ]]; then

        printf 'Отчет по ИБП: apcupsd не отвечает на запрос статуса\n'

        return 0

    fi


    ups_parse


    printf '================================================================\n'

    printf 'Отчет по ИБП (apcupsd)\n'

    printf '================================================================\n'


    printf '\n%-18s %s\n' "Статус:" "${STATUS_RAW:-неизвестно}"

    printf '%-18s %s\n' "Заряд:" "${CHARGE_RAW:-н/д}"

    printf '%-18s %s\n' "Осталось времени:" "${TIMELEFT_RAW:-н/д}"


    printf '\nПороги:\n'

    printf '  Заряд          : WARNING <= %s%% / CRITICAL <= %s%%\n' \
        "${BATTERY_WARNING}" \
        "${BATTERY_CRITICAL}"

    printf '  Время работы   : WARNING < %s мин\n' "${RUNTIME_WARNING}"


    printf '\nОбщий статус: %s\n' "$(ups_current_state)"

    printf '\n'


    return 0
}


# ==============================================================================
# Машинная проверка с уведомлениями
# ==============================================================================

do_check()
{
    #
    # Отсутствие зависимости — пропуск проверки без ошибок.
    #

    if ! command -v "${APCACCESS_BIN}" >/dev/null 2>&1; then

        log_info "UPS" "Пропуск проверки: утилита '${APCACCESS_BIN}' не найдена в системе."

        return 0

    fi


    #
    # Каталог состояния должен существовать ДО захвата блокировки.
    #

    mkdir -p "${STATE_DIR}"


    #
    # Защита от параллельного запуска.
    #

    exec 200>"${LOCK_FILE}"

    if ! flock -n 200; then

        log_info "UPS" "Пропуск: предыдущая проверка выполняется."

        exit 0

    fi


    UPS_STATUS="$(ups_query)"

    if [[ -z "${UPS_STATUS}" ]]; then

        log_warn "UPS" "Пропуск: служба apcupsd не ответила на запрос status."

        return 0

    fi


    ups_parse

    CURRENT_STATE="$(ups_current_state)"


    PREVIOUS_STATE=""

    if [[ -f "${STATE_FILE}" ]]; then

        PREVIOUS_STATE="$(cat "${STATE_FILE}" 2>/dev/null || true)"

    fi


    #
    # Обработка смены состояний и отправка уведомлений
    #

    if [[ "${PREVIOUS_STATE}" != "${CURRENT_STATE}" ]]; then


        if declare -F notify >/dev/null 2>&1; then

            local msg=""

            case "${CURRENT_STATE}" in


                "ON_BATTERY")

                    if [[ "${NOTIFY_ON_BATTERY}" == "true" ]]; then

                        printf -v msg "🔋 ИБП перешел на питание от батареи!\n- Заряд: %s%%\n- Осталось времени: %s" \
                            "${CHARGE_INT}" "${TIMELEFT_RAW:-неизвестно}"

                        notify "ups" "WARNING" "${msg}"

                    fi

                    ;;


                "WARNING")

                    if [[ "${NOTIFY_ON_LOW_BATTERY}" == "true" ]]; then

                        printf -v msg "⚠️ Низкий уровень заряда ИБП!\n- Заряд: %s%%\n- Осталось времени: %s" \
                            "${CHARGE_INT}" "${TIMELEFT_RAW:-неизвестно}"

                        notify "ups" "WARNING" "${msg}"

                    fi

                    ;;


                "LOW_RUNTIME")

                    #
                    # Запас времени ниже RUNTIME_WARNING
                    #

                    if [[ "${NOTIFY_ON_LOW_BATTERY}" == "true" ]]; then

                        printf -v msg "⚠️ Малый остаток времени работы ИБП!\n- Осталось времени: %s (порог: %s мин)\n- Заряд: %s%%" \
                            "${TIMELEFT_RAW:-неизвестно}" "${RUNTIME_WARNING}" "${CHARGE_INT}"

                        notify "ups" "WARNING" "${msg}"

                    fi

                    ;;


                "CRITICAL")

                    if [[ "${NOTIFY_ON_LOW_BATTERY}" == "true" ]]; then

                        printf -v msg "🚨 Критический уровень заряда ИБП!\n- Заряд: %s%%\n- Осталось времени: %s" \
                            "${CHARGE_INT}" "${TIMELEFT_RAW:-неизвестно}"

                        notify "ups" "CRITICAL" "${msg}"

                    fi

                    ;;


                "ONLINE")

                    if [[ -n "${PREVIOUS_STATE}" && "${NOTIFY_ON_RECOVERY}" == "true" ]]; then

                        notify "ups" "OK" "✅ Питание ИБП восстановлено (работа от сети)."

                    fi

                    ;;

            esac

        fi


        #
        # Фиксируем актуальное состояние
        #

        echo "${CURRENT_STATE}" > "${STATE_FILE}"

    fi


    #
    # Module API: ненулевой код означает проблемное состояние.
    #

    case "${CURRENT_STATE}" in

        ONLINE)

            return 0

            ;;

        CRITICAL)

            return 2

            ;;

        *)

            return 1

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
