#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Disk Monitor
# -----------------------------------------------------------------------------

set -Eeuo pipefail

# Сброс локали для стандартизации вывода df
export LC_ALL=C
export LANG=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

#
# Конфигурация
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
CRITICAL="${CRITICAL:-95}"
IGNORE_MOUNTS="${IGNORE_MOUNTS:-}"

STATE_DIR="/var/lib/lsm/state"
LOCK_FILE="${STATE_DIR}/disk_check.lock"
NOTIFY_SCRIPT="${PROJECT_ROOT}/lib/notifications/notify.sh"

# Проверка наличия утилиты
if ! command -v df &>/dev/null; then
    echo "SKIP: Утилита 'df' не найдена в системе."
    exit 0
fi

# Гарантируем наличие директории ДО файла блокировки
mkdir -p "${STATE_DIR}"

(
    # Защита от параллельного запуска
    flock -n 200 || exit 0

    STATUS="OK"
    ALERT_MESSAGES=()

    # Анализируем монтированные разделы через df -P
    while IFS= read -r line; do
        [[ -z "${line}" ]] && continue

        mount_point=$(echo "${line}" | awk '{print $1}')
        usage=$(echo "${line}" | awk '{print $2}')

        if (( usage >= CRITICAL )); then
            STATUS="CRITICAL"
            ALERT_MESSAGES+=("Раздел ${mount_point}: заполнено ${usage}% (Критический порог: ${CRITICAL}%)")
        elif (( usage >= WARNING )); then
            [[ "${STATUS}" != "CRITICAL" ]] && STATUS="WARNING"
            ALERT_MESSAGES+=("Раздел ${mount_point}: заполнено ${usage}% (Порог: ${WARNING}%)")
        fi
    done < <(
        df -P | awk \
            -v warn="${WARNING}" \
            -v ignore="${IGNORE_MOUNTS}" '

        BEGIN {
            split(ignore, a, " ")
            for(i in a) skip[a[i]]=1
        }

        NR > 1 {
            # Пропуск игнорируемых точек монтирования
            if (skip[$6]) next

            # Пропуск псевдо-ФС и виртуальных разделов
            if ($1 ~ /(tmpfs|devtmpfs|loop|cdrom|overlay|squashfs)/) next

            # Удаляем % из значения использования
            gsub(/%/, "", $5)

            if ($5 >= warn) {
                printf "%s %s\n", $6, $5
            }
        }'
    )

    #
    # Отправка уведомлений
    #
    if [[ -f "${NOTIFY_SCRIPT}" ]]; then
        # shellcheck source=/dev/null
        source "${NOTIFY_SCRIPT}"

        if [[ "${STATUS}" != "OK" ]]; then
            DETAILS=$(printf "\n- %s" "${ALERT_MESSAGES[@]}")
            notify "disk" "${STATUS}" "Обнаружено переполнение дисковых разделов:${DETAILS}"
        else
            notify "disk" "OK" "Использование всех дисковых разделов находится в пределах нормы."
        fi
    fi

) 200>"${LOCK_FILE}"
