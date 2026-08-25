#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Модуль мониторинга программных RAID-массивов (mdadm)
#
# Путь:
#   modules/raid/files/check_raid.sh
#
# Назначение:
#   Проверка состояния Linux software RAID массивов через /proc/mdstat
#   и утилиту mdadm. Обнаруживает degraded, failed и inactive массивы.
#
# Режимы:
#
#   check_raid.sh status
#       Краткий текущий статус. Всегда возвращает exit 0.
#
#   check_raid.sh report
#       Подробный отчет по всем массивам. Всегда возвращает exit 0.
#
#   check_raid.sh check
#       Машинная проверка с уведомлениями.
#       Коды выхода: 0 = OK, 1 = WARNING, 2 = CRITICAL/ошибка окружения.
#
# ==============================================================================


set -Eeuo pipefail


#
# Сброс локали для предсказуемого вывода mdadm
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

CONFIG_FILE="/etc/lsm/modules/raid.conf"

if [[ -f "${CONFIG_FILE}" ]]; then

    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"

fi


#
# Значения по умолчанию
#

NOTIFY_ON_FAILURE="${NOTIFY_ON_FAILURE:-true}"

NOTIFY_ON_RECOVERY="${NOTIFY_ON_RECOVERY:-true}"

IGNORE_ARRAYS="${IGNORE_ARRAYS:-}"


#
# Состояние / блокировка
#

STATE_DIR="/var/lib/lsm/state"

STATE_FILE="${STATE_DIR}/raid_alert"

LOCK_FILE="${STATE_DIR}/raid_check.lock"


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
# Вспомогательные функции
# ==============================================================================

#
# Причина пропуска проверки окружения.
# Пустой вывод — окружение пригодно для проверки.
#

raid_env_skip_reason()
{
    if [[ ! -f /proc/mdstat ]]; then

        printf '%s' "Файл /proc/mdstat отсутствует (RAID не используется)."

    elif ! command -v mdadm >/dev/null 2>&1; then

        printf '%s' "Утилита 'mdadm' не найдена в системе."

    elif [[ "${EUID}" -ne 0 ]]; then

        printf '%s' "Для работы с mdadm требуются права root."

    else

        return 1

    fi

    return 0
}


#
# Сканирование массивов.
#
# Результат — глобальные переменные:
#
#   RAID_ARRAYS     список записей "устройство|состояние";
#   ALERT_TRIGGERED 1 — есть проблемный массив;
#   ALERT_MSG       текст проблем (настоящие переводы строк).
#

raid_scan()
{
    RAID_ARRAYS=()

    ALERT_TRIGGERED=0

    ALERT_MSG=""


    local md_name
    local md_device
    local detail
    local state_line
    local skip=false
    local array
    local array_clean


    while IFS= read -r md_name; do

        [[ -z "${md_name}" ]] && continue

        md_device="/dev/${md_name}"


        #
        # Пропуск игнорируемых массивов (поддержка md0 и /dev/md0)
        #

        skip=false

        for array in ${IGNORE_ARRAYS}; do

            array_clean="${array#/dev/}"

            if [[ "${md_name}" == "${array_clean}" ]]; then

                skip=true
                break

            fi

        done

        if [[ "${skip}" == true ]]; then

            continue

        fi


        #
        # Запрос состояния массива
        #

        detail="$(mdadm --detail "${md_device}" 2>/dev/null || true)"

        [[ -z "${detail}" ]] && continue

        state_line="$(printf '%s\n' "${detail}" | grep -i "State :" | sed 's/.*State ://' | xargs || true)"


        #
        # Проверка на сбои (degraded, failed, inactive)
        #

        if printf '%s\n' "${detail}" | grep -i "State :" | grep -qiE "degraded|failed|inactive"; then

            ALERT_TRIGGERED=1

            ALERT_MSG="${ALERT_MSG}"$'\n'"- ${md_device}: ${state_line:-неизвестно}"

            state_line="ПРОБЛЕМА (${state_line:-неизвестно})"

        fi


        RAID_ARRAYS+=("${md_device}|${state_line:-неизвестно}")

    done < <(awk '/^md/ {print $1}' /proc/mdstat 2>/dev/null || true)

    return 0
}


# ==============================================================================
# Краткий статус
# ==============================================================================

do_status()
{
    local reason

    reason="$(raid_env_skip_reason || true)"

    if [[ -n "${reason}" ]]; then

        printf 'RAID: пропуск (%s)\n' "${reason}"

        return 0

    fi


    raid_scan


    if (( ${#RAID_ARRAYS[@]} == 0 )); then

        printf 'RAID: массивы не обнаружены\n'

        return 0

    fi


    local entry
    local device
    local state
    local overall="OK"


    printf 'RAID:\n'

    for entry in "${RAID_ARRAYS[@]}"; do

        device="${entry%%|*}"

        state="${entry#*|}"

        printf '  %s: %s\n' "${device}" "${state}"

        case "${state}" in

            ПРОБЛЕМА*)

                overall="CRITICAL"

                ;;

        esac

    done

    printf 'Итого: %s\n' "${overall}"


    return 0
}


# ==============================================================================
# Подробный отчет
# ==============================================================================

do_report()
{
    local reason

    reason="$(raid_env_skip_reason || true)"

    if [[ -n "${reason}" ]]; then

        printf 'Отчет RAID: пропуск (%s)\n' "${reason}"

        return 0

    fi


    raid_scan


    printf '================================================================\n'

    printf 'Отчет по программным RAID-массивам\n'

    printf '================================================================\n'


    if [[ -n "${IGNORE_ARRAYS}" ]]; then

        printf '\nИгнорируемые массивы: %s\n' "${IGNORE_ARRAYS}"

    fi


    if (( ${#RAID_ARRAYS[@]} == 0 )); then

        printf '\nМассивы не обнаружены.\n\n'

        return 0

    fi


    printf '\n%-14s %s\n' "Устройство" "Состояние"

    printf '%s\n' \
        "------------------------------------------------------------"


    local entry
    local device
    local state

    for entry in "${RAID_ARRAYS[@]}"; do

        device="${entry%%|*}"

        state="${entry#*|}"

        printf '%-14s %s\n' "${device}" "${state}"

    done


    if (( ALERT_TRIGGERED == 1 )); then

        printf '\nОбщий статус: CRITICAL\n\n'

    else

        printf '\nОбщий статус: OK\n\n'

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
    local reason

    reason="$(raid_env_skip_reason || true)"

    if [[ -n "${reason}" ]]; then

        log_info "RAID" "Пропуск проверки: ${reason}"

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

        log_info "RAID" "Пропуск: предыдущая проверка выполняется."

        exit 0

    fi


    raid_scan


    local result=0


    #
    # Отправка оповещений
    #

    if (( ALERT_TRIGGERED == 1 )); then


        #
        # Алерт отправляется один раз, пока проблема не устранена.
        #

        if [[ ! -f "${STATE_FILE}" ]]; then

            touch "${STATE_FILE}"

            log_error "RAID" "Обнаружены проблемы в программном RAID:${ALERT_MSG}"

            if [[ "${NOTIFY_ON_FAILURE}" == "true" ]] &&
               declare -F notify >/dev/null 2>&1; then

                notify "raid" "CRITICAL" "❌ Ошибка в массиве Software RAID:${ALERT_MSG}"

            fi

        fi

        result=2

    else


        #
        # Проблемы устранены: снятие состояния + recovery.
        #

        if [[ -f "${STATE_FILE}" ]]; then

            rm -f "${STATE_FILE}"

            log_success "RAID" "Состояние программных RAID-массивов восстановлено."

            if [[ "${NOTIFY_ON_RECOVERY}" == "true" ]] &&
               declare -F notify >/dev/null 2>&1; then

                notify "raid" "OK" "✅ Состояние Software RAID массивов восстановлено (Healthy)."

            fi

        fi

    fi


    #
    # Module API: ненулевой код означает проблемное состояние.
    #

    return "${result}"
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
