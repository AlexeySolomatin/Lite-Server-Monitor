#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Disk Monitor
#
# Путь:
#   modules/disk/files/check_disk.sh
#
# Назначение:
#   Проверка использования файловых систем.
#
# Поддерживаемые режимы:
#
#   check_disk.sh status
#       Краткий текущий статус.
#
#   check_disk.sh report
#       Подробный отчет по файловым системам.
#
#   check_disk.sh check
#       Машинная проверка состояния.
#       В этом режиме также выполняются уведомления.
#
# ВАЖНО:
#
#   Этот скрипт НЕ управляет notification state.
#
#   Состояние уведомлений:
#
#       /var/lib/lsm/state/disk.state
#
#   полностью принадлежит:
#
#       lib/notifications/notify.sh
#
#   check_disk.sh только передает результат:
#
#       notify "disk" "OK|WARNING|CRITICAL" "..."
#
# ==============================================================================


set -Eeuo pipefail



#
# Стандартизация вывода df.
#

export LC_ALL=C
export LANG=C



#
# Каталоги проекта
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"



#
# Библиотека журналирования
#

if [[ -f "${PROJECT_ROOT}/lib/core/common.sh" ]]; then

    # shellcheck source=/dev/null
    source "${PROJECT_ROOT}/lib/core/common.sh"

fi

if [[ -f "${PROJECT_ROOT}/lib/core/logging.sh" ]]; then

    # shellcheck source=/dev/null
    source "${PROJECT_ROOT}/lib/core/logging.sh"

fi

if ! declare -F log_info >/dev/null 2>&1; then

    log_info()
    {
        printf '%s\n' "$*"
    }

fi



#
# Конфигурация модуля
#

CONFIG_FILE="/etc/lsm/modules/disk.conf"



if [[ -f "${CONFIG_FILE}" ]]; then

    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"

fi



#
# Значения по умолчанию
#

WARNING="${WARNING:-80}"

CRITICAL="${CRITICAL:-90}"

IGNORE_MOUNTS="${IGNORE_MOUNTS:-}"

NOTIFY_ON_ALERT="${NOTIFY_ON_ALERT:-true}"

NOTIFY_ON_RECOVERY="${NOTIFY_ON_RECOVERY:-true}"



#
# Состояние / блокировка
#
# ВАЖНО:
#
# LOCK_FILE находится в каталоге state, но сам disk.state
# здесь НЕ создается и НЕ изменяется.
#

STATE_DIR="${STATE_DIR:-/var/lib/lsm/state}"

LOCK_FILE="${STATE_DIR}/disk_check.lock"



#
# Система уведомлений
#

NOTIFY_SCRIPT="${PROJECT_ROOT}/lib/notifications/notify.sh"



#
# Режим работы
#

MODE="${1:-check}"



# ==============================================================================
# Вспомогательные функции
# ==============================================================================

#
# Вывод ошибки.
#

disk_error()
{
    printf 'ERROR: %s\n' "$*" >&2
}



#
# Вывод предупреждения.
#

disk_warn()
{
    printf 'WARNING: %s\n' "$*" >&2
}



#
# Проверка числового значения.
#

disk_is_number()
{
    [[ "${1:-}" =~ ^[0-9]+$ ]]
}



#
# Проверка конфигурации.
#

disk_validate_config()
{
    if ! disk_is_number "${WARNING}" ||
       ! disk_is_number "${CRITICAL}"; then

        disk_error \
            "WARNING и CRITICAL должны быть целыми числами."

        return 1

    fi



    if (( WARNING < 0 || WARNING > 100 )); then

        disk_error \
            "WARNING должен находиться в диапазоне 0..100."

        return 1

    fi



    if (( CRITICAL < 0 || CRITICAL > 100 )); then

        disk_error \
            "CRITICAL должен находиться в диапазоне 0..100."

        return 1

    fi



    if (( WARNING >= CRITICAL )); then

        disk_error \
            "WARNING должен быть меньше CRITICAL."

        return 1

    fi



    return 0
}



#
# Проверка наличия df.
#

disk_require_df()
{
    if ! command -v df >/dev/null 2>&1; then

        disk_error \
            "Утилита 'df' не найдена в системе."

        return 1

    fi



    return 0
}



#
# Проверка наличия notify.sh.
#

disk_notify_available()
{
    [[ -f "${NOTIFY_SCRIPT}" ]]
}



# ==============================================================================
# Сбор информации о файловых системах
# ==============================================================================

#
# Формат вывода:
#
#   mount_point|usage
#
# Например:
#
#   /|73
#   /home|82
#
# Внутри функции не выполняются уведомления.
#

disk_collect_filesystems()
{
    df -P 2>/dev/null |
        awk \
            -v ignore="${IGNORE_MOUNTS}" '
        BEGIN {
            n = split(ignore, ignored, " ")
        }

        NR == 1 {
            next
        }

        {
            filesystem = $1
            usage = $5
            mount_point = $6

            #
            # Некоторые реализации df могут переносить имя
            # файловой системы. Такие строки здесь пропускаем.
            #
            if (usage !~ /^[0-9]+%$/) {
                next
            }

            #
            # Удаляем процент.
            #
            gsub(/%/, "", usage)

            #
            # Пропуск виртуальных / псевдо-ФС.
            #
            # ВАЖНО: mawk (awk по умолчанию в Ubuntu) не допускает
            # перевод строки сразу после "if (" — условие держим
            # на одной строке.
            #
            if (filesystem ~ /^(proc|sysfs|devtmpfs|devpts|tmpfs|cgroup|cgroup2|pstore|bpf|debugfs|tracefs|securityfs|configfs|fusectl|mqueue|hugetlbfs|autofs|binfmt_misc|ramfs|overlay|squashfs|nsfs)/) {
                next
            }

            #
            # Пропуск loop / cdrom устройств.
            #
            if (filesystem ~ /^\/dev\/loop/ || filesystem ~ /^\/dev\/sr/) {
                next
            }

            #
            # Проверка списка IGNORE_MOUNTS.
            #
            skip = 0

            for (i = 1; i <= n; i++) {

                if (ignored[i] == "") {
                    continue
                }

                #
                # Точное совпадение:
                #
                # /var
                #
                if (mount_point == ignored[i]) {
                    skip = 1
                    break
                }

                #
                # Вложенный путь:
                #
                # /var/log
                # при IGNORE_MOUNTS=/var
                #
                if (index(mount_point, ignored[i] "/") == 1) {
                    skip = 1
                    break
                }
            }

            if (skip) {
                next
            }

            printf "%s|%s\n", mount_point, usage
        }'
}



# ==============================================================================
# Определение общего состояния
# ==============================================================================

#
# Результат:
#
#   OK
#   WARNING
#   CRITICAL
#
# ALERT_MESSAGES заполняется вызывающим кодом.
#

disk_evaluate()
{
    local mount_point
    local usage

    STATUS="OK"

    ALERT_MESSAGES=()



    while IFS='|' read -r mount_point usage
    do

        [[ -z "${mount_point}" ]] && continue

        [[ -z "${usage}" ]] && continue



        if (( usage >= CRITICAL )); then

            STATUS="CRITICAL"

            ALERT_MESSAGES+=(
                "Раздел ${mount_point}: заполнено ${usage}% (критический порог: ${CRITICAL}%)"
            )



        elif (( usage >= WARNING )); then

            if [[ "${STATUS}" != "CRITICAL" ]]; then

                STATUS="WARNING"

            fi



            ALERT_MESSAGES+=(
                "Раздел ${mount_point}: заполнено ${usage}% (порог предупреждения: ${WARNING}%)"
            )

        fi



    done < <(
        disk_collect_filesystems
    )



    return 0
}



# ==============================================================================
# Формирование текста уведомления
# ==============================================================================

disk_build_alert_message()
{
    local status="${1:-OK}"



    if [[ "${status}" == "OK" ]]; then

        printf '%s\n' \
            "Использование всех контролируемых файловых систем находится в пределах нормы."

        return 0

    fi



    printf '%s\n' \
        "Обнаружены проблемы с использованием дискового пространства:"



    local message



    for message in "${ALERT_MESSAGES[@]}"
    do

        printf -- "- %s\n" "${message}"

    done

}



# ==============================================================================
# Отправка уведомления
# ==============================================================================

#
# ВАЖНО:
#
# Уведомления выполняются только из режима CHECK.
#
# status/report не должны вызывать notify(), поскольку обычное
# формирование отчета не должно:
#
#   - менять notification state;
#   - запускать throttling;
#   - создавать recovery;
#   - отправлять повторные alert.
#

disk_send_notification()
{
    local status="${1:-OK}"

    local message



    if ! disk_notify_available; then

        disk_warn \
            "Модуль уведомлений отсутствует: ${NOTIFY_SCRIPT}"

        return 0

    fi



    #
    # Подключаем notify.sh.
    #
    # При source его блок прямого запуска НЕ выполняется.
    #

    # shellcheck source=/dev/null
    source "${NOTIFY_SCRIPT}"



    if ! declare -f notify >/dev/null 2>&1; then

        disk_warn \
            "Функция notify() недоступна."

        return 0

    fi



    message="$(disk_build_alert_message "${status}")"



    #
    # notify.sh самостоятельно отвечает за:
    #
    #   - state;
    #   - throttling;
    #   - escalation;
    #   - recovery.
    #

    notify \
        "disk" \
        "${status}" \
        "${message}"

}



# ==============================================================================
# Краткий статус
# ==============================================================================

disk_status()
{
    local status



    if ! disk_require_df; then

        return 1

    fi



    if ! disk_validate_config; then

        return 1

    fi



    disk_evaluate



    status="${STATUS}"



    printf 'Диски: %s\n' "${status}"



    #
    # Статус — информационный режим:
    # предупреждения НЕ влияют на код выхода.
    #

    return 0

}



# ==============================================================================
# Подробный отчет
# ==============================================================================

disk_report()
{
    if ! disk_require_df; then

        printf 'Мониторинг дисков: недоступен\n'

        return 1

    fi



    if ! disk_validate_config; then

        printf 'Мониторинг дисков: некорректная конфигурация\n'

        return 1

    fi



    local filesystem
    local mount_point
    local usage
    local status



    disk_evaluate

    status="${STATUS}"



    printf 'Мониторинг дисков\n'

    printf '-----------------\n'

    printf 'Порог предупреждения : %s%%\n' "${WARNING}"

    printf 'Критический порог    : %s%%\n' "${CRITICAL}"



    if [[ -n "${IGNORE_MOUNTS}" ]]; then

        printf 'Игнорируемые точки   : %s\n' "${IGNORE_MOUNTS}"

    else

        printf 'Игнорируемые точки   : нет\n'

    fi



    printf 'Статус               : %s\n' "${status}"



    printf '\n'

    printf '%-35s %10s %12s\n' \
        "Точка монтирования" \
        "Занято" \
        "Состояние"



    printf '%-35s %10s %12s\n' \
        "-----------------------------------" \
        "----------" \
        "------------"



    while IFS='|' read -r mount_point usage
    do

        [[ -z "${mount_point}" ]] && continue

        [[ -z "${usage}" ]] && continue



        local mount_status="OK"



        if (( usage >= CRITICAL )); then

            mount_status="CRITICAL"

        elif (( usage >= WARNING )); then

            mount_status="WARNING"

        fi



        printf '%-35s %9s%% %12s\n' \
            "${mount_point}" \
            "${usage}" \
            "${mount_status}"



    done < <(
        disk_collect_filesystems
    )



    printf '\n'



    if [[ "${status}" == "OK" ]]; then

        printf '%s\n' \
            "Все контролируемые файловые системы находятся в пределах нормы."

    else

        printf '%s\n' \
            "Обнаруженные проблемы:"



        local message



        for message in "${ALERT_MESSAGES[@]}"
        do

            printf -- "- %s\n" "${message}"

        done

    fi



    #
    # REPORT не отправляет уведомления.
    #

    return 0

}



# ==============================================================================
# Машинная проверка
# ==============================================================================

disk_check()
{
    if ! disk_require_df; then

        #
        # Отсутствие обязательной утилиты является ошибкой самого
        # мониторинга, а не состоянием диска.
        #

        return 2

    fi



    if ! disk_validate_config; then

        return 2

    fi



    disk_evaluate



    #
    # Уведомление выполняется именно здесь.
    #

    case "${STATUS}" in

        OK)

            if [[ "${NOTIFY_ON_RECOVERY}" == "true" ]]; then

                disk_send_notification "OK"

            fi

            ;;


        WARNING|CRITICAL)

            if [[ "${NOTIFY_ON_ALERT}" == "true" ]]; then

                disk_send_notification "${STATUS}"

            fi

            ;;


        *)

            return 2

            ;;

    esac



    #
    # Module API получает ненулевой код при проблемном состоянии.
    #
    # Это позволяет module_api_check_all() учитывать модуль как failed.
    #

    case "${STATUS}" in

        OK)

            return 0

            ;;

        WARNING|CRITICAL)

            return 1

            ;;

        *)

            return 2

            ;;

    esac

}



# ==============================================================================
# Основной диспетчер режимов Module API
# ==============================================================================

main()
{
    case "${MODE}" in

        status)

            disk_status

            ;;


        report)

            disk_report

            ;;


        check)

            disk_check

            ;;


        *)

            disk_error \
                "Неизвестный режим: ${MODE}"

            printf '%s\n' \
                "Использование: $0 {status|report|check}" \
                >&2

            return 2

            ;;

    esac

}



# ==============================================================================
# Основной запуск с блокировкой
# ==============================================================================

#
# Каталог блокировки нужен для защиты от одновременного запуска
# двух экземпляров одного disk-check.
#
# Сам notification state здесь НЕ используется.
#

mkdir -p "${STATE_DIR}"



#
# Все режимы используют один lock.
#
# Это предотвращает одновременное чтение/проверку одного и того же
# набора файловых систем несколькими экземплярами.
#

(
    if ! flock -n 200; then

        log_info "DISK" "Пропуск: предыдущая проверка еще выполняется."

        exit 0

    fi

    main

) 200>"${LOCK_FILE}"
