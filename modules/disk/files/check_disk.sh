```bash
#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Disk Monitor
#
# Путь:
#   modules/disk/files/check_disk.sh
#
# Назначение:
#   Контроль заполнения файловых систем.
#
# Поддерживаемый интерфейс:
#
#   check_disk.sh status
#       Краткий текущий статус.
#
#   check_disk.sh report
#       Подробный отчет.
#
#   check_disk.sh check
#       Машинная проверка состояния.
#
# Без аргумента:
#   выполняется check для обратной совместимости.
#
# -----------------------------------------------------------------------------

set -Eeuo pipefail


#
# Сброс локали для стандартизации вывода df.
#

export LC_ALL=C
export LANG=C


#
# Каталог скрипта.
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


#
# Корень проекта.
#
# /opt/lsm/modules/disk/files
#       ↑
# Поднимаемся на 3 уровня:
#
# files -> disk -> modules -> lsm
#

PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"


#
# Загрузка централизованных библиотек.
#

if [[ -f "${PROJECT_ROOT}/lib/core/logging.sh" ]]; then

    # shellcheck source=/dev/null
    source "${PROJECT_ROOT}/lib/core/logging.sh"

fi


#
# Компонент логирования.
#

readonly DISK_COMPONENT="DISK"


#
# Конфигурация.
#

CONFIG_FILE="/etc/lsm/modules/disk.conf"

if [[ -f "${CONFIG_FILE}" ]]; then

    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"

fi


#
# Значения по умолчанию.
#

WARNING="${WARNING:-80}"

CRITICAL="${CRITICAL:-90}"

IGNORE_MOUNTS="${IGNORE_MOUNTS:-}"

NOTIFY_ON_ALERT="${NOTIFY_ON_ALERT:-true}"

NOTIFY_ON_RECOVERY="${NOTIFY_ON_RECOVERY:-true}"


#
# Пути состояния.
#

STATE_DIR="${LSM_STATE_DIR:-/var/lib/lsm/state}"

STATE_FILE="${STATE_DIR}/disk.state"

LOCK_FILE="${STATE_DIR}/disk_check.lock"


#
# Система уведомлений.
#

NOTIFY_SCRIPT="${PROJECT_ROOT}/lib/notifications/notify.sh"


#
# Результат проверки.
#

STATUS="OK"

ALERT_MESSAGES=()


# ==============================================================================
# Вспомогательные функции
# ==============================================================================


#
# Проверка доступности df.
#

check_df_available()
{

    if command -v df >/dev/null 2>&1; then

        return 0

    fi


    printf '%s\n' \
        "Утилита 'df' не найдена в системе." >&2


    return 1

}



#
# Запись state-файла.
#
# State существует только при проблемном состоянии.
#

write_alert_state()
{

    local message

    mkdir -p "${STATE_DIR}"


    {
        printf '%s\n' \
            "status=${STATUS}"

        printf '%s\n' \
            "timestamp=%s" \
            "$(date '+%Y-%m-%d %H:%M:%S')"

        for message in "${ALERT_MESSAGES[@]}"
        do

            printf '%s\n' \
                "${message}"

        done

    } > "${STATE_FILE}"

}



#
# Удаление state-файла после восстановления.
#

clear_alert_state()
{

    rm -f "${STATE_FILE}" 2>/dev/null || true

}



#
# Выполнение проверки файловых систем.
#

run_disk_check()
{

    STATUS="OK"

    ALERT_MESSAGES=()


    #
    # Проверяем df.
    #

    if ! check_df_available; then

        STATUS="FAIL"

        ALERT_MESSAGES+=(
            "Утилита df недоступна."
        )

        return 1

    fi


    #
    # Проверяем конфигурационные пороги.
    #

    if ! [[ "${WARNING}" =~ ^[0-9]+$ &&
            "${CRITICAL}" =~ ^[0-9]+$ ]]; then

        STATUS="FAIL"

        ALERT_MESSAGES+=(
            "Некорректные пороги WARNING=${WARNING}, CRITICAL=${CRITICAL}."
        )

        return 1

    fi


    if (( WARNING >= CRITICAL )); then

        STATUS="FAIL"

        ALERT_MESSAGES+=(
            "Некорректная конфигурация: WARNING должен быть меньше CRITICAL."
        )

        return 1

    fi


    #
    # Анализируем файловые системы.
    #
    # df -P гарантирует POSIX-формат одной строкой на файловую систему.
    #

    local mount_point

    local usage



    while IFS=$'\t' read -r mount_point usage
    do

        [[ -n "${mount_point}" ]] || continue

        [[ -n "${usage}" ]] || continue


        if (( usage >= CRITICAL )); then

            STATUS="CRITICAL"

            ALERT_MESSAGES+=(
                "Раздел ${mount_point}: заполнено ${usage}% (критический порог: ${CRITICAL}%)."
            )


        elif (( usage >= WARNING )); then

            if [[ "${STATUS}" != "CRITICAL" ]]; then

                STATUS="WARNING"

            fi


            ALERT_MESSAGES+=(
                "Раздел ${mount_point}: заполнено ${usage}% (порог: ${WARNING}%)."
            )

        fi


    done < <(

        df -P \
            | awk \
                -v ignore="${IGNORE_MOUNTS}" '

        BEGIN {

            n = split(ignore, a, " ")

        }

        NR > 1 {

            #
            # Пропуск игнорируемых точек монтирования.
            #

            skip = 0

            for (i = 1; i <= n; i++) {

                if (a[i] != "" &&
                    ($6 == a[i] || index($6, a[i] "/") == 1)) {

                    skip = 1

                    break

                }

            }

            if (skip) {
                next
            }


            #
            # Пропуск псевдо-ФС и виртуальных файловых систем.
            #

            if ($1 ~ /(tmpfs|devtmpfs|loop|cdrom|overlay|squashfs)/) {
                next
            }


            #
            # Удаляем процент.
            #

            gsub(/%/, "", $5)


            #
            # Передаем все файловые системы.
            # Порог проверяется уже в Bash.
            #

            printf "%s\t%s\n", $6, $5

        }'

    )


    #
    # Обновляем state.
    #

    if [[ "${STATUS}" == "OK" ]]; then

        clear_alert_state

    else

        write_alert_state

    fi


    #
    # Возвращаем ошибочный код только для FAIL/CRITICAL.
    #
    # WARNING остается предупреждением.
    #

    case "${STATUS}" in

        OK)

            return 0

            ;;


        WARNING)

            return 0

            ;;


        CRITICAL|FAIL)

            return 1

            ;;


        *)

            return 1

            ;;

    esac

}



# ==============================================================================
# Уведомления
# ==============================================================================


send_notification()
{

    #
    # Если notify.sh отсутствует,
    # проверка системы все равно считается выполненной.
    #

    if [[ ! -f "${NOTIFY_SCRIPT}" ]]; then

        log_warn \
            "${DISK_COMPONENT}" \
            "Система уведомлений недоступна: ${NOTIFY_SCRIPT}" \
            >&2

        return 0

    fi


    #
    # Загружаем существующий API notify.sh.
    #

    # shellcheck source=/dev/null
    source "${NOTIFY_SCRIPT}"


    #
    # Проверяем наличие функции notify.
    #

    if ! declare -f notify >/dev/null 2>&1; then

        log_warn \
            "${DISK_COMPONENT}" \
            "Функция notify() отсутствует в ${NOTIFY_SCRIPT}" \
            >&2

        return 0

    fi


    local details


    if [[ "${STATUS}" == "OK" ]]; then


        if [[ "${NOTIFY_ON_RECOVERY}" != "true" ]]; then

            return 0

        fi


        notify \
            "disk" \
            "OK" \
            "Использование всех дисковых разделов находится в пределах нормы."


    else


        if [[ "${NOTIFY_ON_ALERT}" != "true" ]]; then

            return 0

        fi


        details="$(
            printf '\n- %s' "${ALERT_MESSAGES[@]}"
        )"


        notify \
            "disk" \
            "${STATUS}" \
            "Обнаружена проблема с заполнением дисковых разделов:${details}"

    fi

}



# ==============================================================================
# Краткий статус
# ==============================================================================

disk_status()
{

    if ! run_disk_check; then

        case "${STATUS}" in

            FAIL|CRITICAL)

                printf '[FAIL] Disk: %s\n' \
                    "${STATUS}"

                return 1

                ;;

        esac

    fi


    case "${STATUS}" in

        OK)

            printf '[ OK ] Дисковые разделы в норме\n'

            ;;


        WARNING)

            printf '[WARN] Обнаружены предупреждения по заполнению дисков\n'

            printf '       %s\n' \
                "${ALERT_MESSAGES[@]}"

            ;;


        CRITICAL)

            printf '[FAIL] Критическое заполнение дисковых разделов\n'

            printf '       %s\n' \
                "${ALERT_MESSAGES[@]}"

            return 1

            ;;


        FAIL)

            printf '[FAIL] Проверка дисков не выполнена\n'

            printf '       %s\n' \
                "${ALERT_MESSAGES[@]}"

            return 1

            ;;

    esac

}



# ==============================================================================
# Подробный отчет
# ==============================================================================

disk_report()
{

    run_disk_check || true


    printf 'Состояние дисков: %s\n' "${STATUS}"

    printf 'WARNING threshold : %s%%\n' "${WARNING}"

    printf 'CRITICAL threshold: %s%%\n' "${CRITICAL}"


    if [[ -n "${IGNORE_MOUNTS}" ]]; then

        printf 'Игнорируемые точки: %s\n' \
            "${IGNORE_MOUNTS}"

    else

        printf 'Игнорируемые точки: нет\n"

    fi


    printf '\n'


    case "${STATUS}" in

        OK)

            printf '[ OK ] Все контролируемые файловые системы в норме.\n'

            ;;


        WARNING)

            printf '[WARN] Обнаружены предупреждения:\n'

            printf '  - %s\n' \
                "${ALERT_MESSAGES[@]}"

            ;;


        CRITICAL)

            printf '[FAIL] Обнаружены критические проблемы:\n'

            printf '  - %s\n' \
                "${ALERT_MESSAGES[@]}"

            ;;


        FAIL)

            printf '[FAIL] Проверка не выполнена:\n'

            printf '  - %s\n' \
                "${ALERT_MESSAGES[@]}"

            ;;

    esac

}



# ==============================================================================
# Машинная проверка
# ==============================================================================

disk_check()
{

    if run_disk_check; then

        case "${STATUS}" in

            OK)

                log_success \
                    "${DISK_COMPONENT}" \
                    "Все контролируемые файловые системы в норме." \
                    >&2

                return 0

                ;;


            WARNING)

                log_warn \
                    "${DISK_COMPONENT}" \
                    "${ALERT_MESSAGES[*]}" \
                    >&2

                return 0

                ;;

        esac

    fi


    log_fail \
        "${DISK_COMPONENT}" \
        "${ALERT_MESSAGES[*]:-Проверка дисков завершилась ошибкой.}" \
        >&2


    return 1

}



# ==============================================================================
# Основной запуск проверки с блокировкой
# ==============================================================================

run_locked_check()
{

    mkdir -p "${STATE_DIR}"


    (
        #
        # Защита от параллельного запуска.
        #

        flock -n 200 || exit 0


        #
        # Выполняем проверку.
        #

        run_disk_check


        #
        # Уведомление отправляется только при обычном запуске проверки.
        #

        send_notification

    ) 200>"${LOCK_FILE}"

}



# ==============================================================================
# CLI
# ==============================================================================

MODE="${1:-check}"


case "${MODE}" in


    status)

        #
        # status не отправляет уведомления.
        #

        run_disk_check

        disk_status

        ;;


    report)

        #
        # report не отправляет уведомления.
        #

        disk_report

        ;;


    check)

        #
        # check:
        #
        #   - выполняет проверку;
        #   - обновляет state;
        #   - отправляет уведомление.
        #

        run_locked_check

        disk_check

        ;;


    *)

        log_error \
            "${DISK_COMPONENT}" \
            "Неизвестный режим: ${MODE}. Используйте status, report или check." \
            >&2

        exit 2

        ;;

esac
```
