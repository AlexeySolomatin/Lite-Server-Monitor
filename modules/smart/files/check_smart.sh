#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Модуль мониторинга здоровья накопителей по SMART
#
# Путь:
#   modules/smart/files/check_smart.sh
#
# Назначение:
#   Периодическая проверка состояния физических дисков (HDD/SSD)
#   через утилиту smartctl из пакета smartmontools.
#
#   Модуль определяет накопители автоматически, сравнивает их
#   состояние со здоровым эталоном и отправляет уведомления:
#
#       - CRITICAL — при обнаружении сбоя SMART;
#       - OK (recovery) — при восстановлении статуса после сбоя.
#
# Режимы:
#
#   check_smart.sh status
#       Краткий текущий статус. Всегда возвращает exit 0.
#
#   check_smart.sh report
#       Подробный отчет по всем накопителям, включая температуру
#       (при REPORT_TEMPERATURE=true). Всегда возвращает exit 0.
#
#   check_smart.sh check
#       Машинная проверка с уведомлениями.
#       Коды выхода: 0 = OK, 1 = WARNING, 2 = CRITICAL/ошибка окружения.
#
# ==============================================================================


set -Eeuo pipefail


#
# Сброс локали для предсказуемого вывода smartctl
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

CONFIG_FILE="/etc/lsm/modules/smart.conf"

if [[ -f "${CONFIG_FILE}" ]]; then

    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"

fi


#
# Значения по умолчанию
#

IGNORE_DEVICES="${IGNORE_DEVICES:-}"

NOTIFY_ON_FAILURE="${NOTIFY_ON_FAILURE:-true}"

NOTIFY_ON_RECOVERY="${NOTIFY_ON_RECOVERY:-true}"

REPORT_TEMPERATURE="${REPORT_TEMPERATURE:-true}"


#
# Состояние / блокировка
#

STATE_DIR="/var/lib/lsm/state"

LOCK_FILE="${STATE_DIR}/smart_check.lock"


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
# Проверка, входит ли устройство в список игнорируемых.
#
# Сравнение нормализуется через basename:
# пользователь может указать как "sda", так и "/dev/sda".
#

smart_is_ignored()
{
    local dev_name
    local entry
    local entry_name

    dev_name="$(basename "${1}")"

    for entry in ${IGNORE_DEVICES}; do

        entry_name="$(basename "${entry}")"

        if [[ "${dev_name}" == "${entry_name}" ]]; then
            return 0
        fi

    done

    return 1
}


#
# Список физических накопителей.
#

smart_list_devices()
{
    #
    # Только физические диски (TYPE=disk): разделы sda1/sda2 и
    # прочие не должны попадать в отчет и в проверку.
    #

    if command -v lsblk >/dev/null 2>&1; then

        lsblk -dn -o NAME,TYPE 2>/dev/null \
            | awk '$2 == "disk" { print "/dev/" $1 }' \
            | sort \
            || true

        return 0

    fi

    #
    # Fallback: find без разделов (sdX / nvmeXnY без цифры на конце).
    #

    find /dev \
        -maxdepth 1 \
        -type b \
        \( \
            -name "sd[a-z]" \
            -o -name "nvme[0-9]n[0-9]" \
            -o -name "vd[a-z]" \
            -o -name "xvd[a-z]" \
        \) \
        2>/dev/null | sort || true
}


#

smart_health_rc()
{
    local rc=0

    smartctl -H "${1}" >/dev/null 2>&1 || rc=$?

    printf '%s' "${rc}"
}


#
# Температура устройства (только отображение, без алертов).
#
# Источник — атрибуты 194 (Temperature_Celsius) или 190
# (Airflow_Temperature_Celsius) из таблицы smartctl -A;
# Для NVME используется строка "Temperature:".
# При неудаче возвращается "н/д".
#

smart_get_temperature()
{
    local disk="${1}"
    local output=""
    local temp=""

    output="$(smartctl -A "${disk}" 2>/dev/null || true)"

    if [[ -z "${output}" ]]; then
        printf '%s' "н/д"
        return 0
    fi

    temp="$(
        printf '%s\n' "${output}" |
        awk '$1 == "194" || $1 == "190" || $2 == "Temperature_Celsius" { print $NF }' |
        tail -n 1
    )"

    if [[ -z "${temp}" ]]; then
        temp="$(
            printf '%s\n' "${output}" |
            awk '/^Temperature:/ { print $2 }' |
            tail -n 1
        )"
    fi

    if [[ "${temp}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        printf '%s' "${temp}"
    else
        printf '%s' "н/д"
    fi
}


#
# Заполнение списка проверяемых устройств.
# Результат — глобальный массив SMART_DISKS.
#

smart_collect_disks()
{
    local disk

    SMART_DISKS=()

    while IFS= read -r disk; do

        [[ -z "${disk}" ]] && continue

        smart_is_ignored "${disk}" && continue

        SMART_DISKS+=("${disk}")

    done < <(smart_list_devices)

    return 0
}


# ==============================================================================
# Краткий статус
# ==============================================================================

do_status()
{
    if ! command -v smartctl >/dev/null 2>&1; then

        printf 'SMART: недоступно (smartmontools не установлен)\n'

        return 0

    fi


    local disk
    local rc
    local overall="OK"
    local found=0


    smart_collect_disks

    if (( ${#SMART_DISKS[@]} == 0 )); then

        printf 'SMART: физические накопители не обнаружены\n'

        return 0

    fi


    printf 'SMART:\n'

    for disk in "${SMART_DISKS[@]}"; do

        found=$((found + 1))

        rc="$(smart_health_rc "${disk}")"

        if (( rc != 0 )); then

            printf '  %s: СБОЙ (код smartctl: %s)\n' "${disk}" "${rc}"

            overall="CRITICAL"

        else

            printf '  %s: OK\n' "${disk}"

        fi

    done


    printf 'Итого: %s (%d нак.)\n' "${overall}" "${found}"


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
    if ! command -v smartctl >/dev/null 2>&1; then

        printf 'Отчет SMART: недоступно (smartmontools не установлен)\n'

        return 0

    fi


    local disk
    local rc
    local temp
    local overall="OK"
    local failed=0
    local total=0


    smart_collect_disks

    total=${#SMART_DISKS[@]}


    printf '================================================================\n'

    printf 'Отчет SMART\n'

    printf '================================================================\n'


    if (( total == 0 )); then

        printf '\nФизические накопители не обнаружены.\n\n'

        return 0

    fi


    printf '\nВсего накопителей : %d\n' "${total}"

    printf 'Игнорируемые      : %s\n' "${IGNORE_DEVICES:-нет}"


    if [[ "${REPORT_TEMPERATURE}" == "true" ]]; then

        printf '\n%-14s %12s %14s\n' \
            "Устройство" \
            "Состояние" \
            "Температура"

        printf '%s\n' \
            "------------------------------------------------------------"

        for disk in "${SMART_DISKS[@]}"; do

            rc="$(smart_health_rc "${disk}")"

            if (( rc != 0 )); then

                overall="CRITICAL"
                failed=$((failed + 1))

                printf '%-14s %12s %14s\n' \
                    "${disk}" \
                    "СБОЙ (${rc})" \
                    "н/д"

            else

                temp="$(smart_get_temperature "${disk}")"

                printf '%-14s %12s %13s°C\n' \
                    "${disk}" \
                    "OK" \
                    "${temp}"

            fi

        done

    else

        printf '\n%-14s %s\n' "Устройство" "Состояние"

        printf '%s\n' \
            "------------------------------------------------------------"

        for disk in "${SMART_DISKS[@]}"; do

            rc="$(smart_health_rc "${disk}")"

            if (( rc != 0 )); then

                overall="CRITICAL"
                failed=$((failed + 1))

                printf '%-14s %s\n' "${disk}" "СБОЙ (код smartctl: ${rc})"

            else

                printf '%-14s %s\n' "${disk}" "OK"

            fi

        done

    fi


    printf '\nОбщий статус: %s\n' "${overall}"


    if (( failed > 0 )); then

        printf 'Накопителей со сбоем SMART: %d. Требуется проверка и резервное копирование данных.\n' \
            "${failed}"

    fi


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
    # Отсутствие зависимости — пропуск проверки без ошибок.
    #

    if ! command -v smartctl >/dev/null 2>&1; then

        log_info "SMART" "Пропуск проверки: утилита 'smartctl' не найдена в системе (пакет smartmontools не установлен)."

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

        log_info "SMART" "Пропуск: предыдущая проверка выполняется."

        exit 0

    fi


    local disk
    local disk_name
    local rc
    local result=0
    local state_file


    smart_collect_disks


    for disk in "${SMART_DISKS[@]}"; do

        disk_name="$(basename "${disk}")"

        state_file="${STATE_DIR}/smart_alert_${disk_name}"


        #
        # Проверка здоровья накопителя.
        #

        rc=0
        smartctl -H "${disk}" >/dev/null 2>&1 || rc=$?


        if (( rc != 0 )); then

            #
            # Сбой: алерт отправляется один раз (per-disk state).
            #

            if [[ ! -f "${state_file}" ]]; then

                touch "${state_file}"

                log_error "SMART" "Ошибка SMART на устройстве ${disk} (код smartctl: ${rc})."

                if [[ "${NOTIFY_ON_FAILURE}" == "true" ]] &&
                   declare -F notify >/dev/null 2>&1; then

                    notify \
                        "smart" \
                        "CRITICAL" \
                        "❌ Обнаружен сбой SMART на устройстве ${disk} (код smartctl: ${rc}). Рекомендуется проверить диск и наличие резервных копий."

                fi

            fi

            result=2

        else

            #
            # Здоров: снятие per-disk state + recovery.
            #

            if [[ -f "${state_file}" ]]; then

                rm -f "${state_file}"

                log_success "SMART" "Статус SMART устройства ${disk} восстановлен."

                if [[ "${NOTIFY_ON_RECOVERY}" == "true" ]] &&
                   declare -F notify >/dev/null 2>&1; then

                    notify \
                        "smart" \
                        "OK" \
                        "✅ Статус SMART устройства ${disk} восстановлен."

                fi

            fi

        fi

    done


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
