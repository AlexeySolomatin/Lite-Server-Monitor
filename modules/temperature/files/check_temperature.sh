#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Temperature Monitor
# -----------------------------------------------------------------------------

set -Eeuo pipefail

# Сброс локали
export LC_ALL=C
export LANG=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

#
# Конфигурация
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

STATE_DIR="/var/lib/lsm/state"
STATE_FILE="${STATE_DIR}/temperature_alert"
LOCK_FILE="${STATE_DIR}/temperature_check.lock"
NOTIFY_SCRIPT="${PROJECT_ROOT}/lib/notifications/notify.sh"

# Гарантируем наличие директории ДО открытия файла блокировки
mkdir -p "${STATE_DIR}"

(
    # Защита от параллельного запуска
    flock -n 200 || exit 0

    HIGHEST_TEMP=0

    #
    # 1. Попытка получить температуру через утилиту 'sensors'
    #
    if command -v sensors &>/dev/null; then
        TEMP_DATA=$(sensors 2>/dev/null || true)
        if [[ -n "${TEMP_DATA}" ]]; then
            PARSED_MAX=$(
                echo "${TEMP_DATA}" |
                grep -oE '\+[0-9]+(\.[0-9]+)?°C' |
                tr -d '+°C' |
                awk '{print int($1)}' |
                sort -nr |
                head -1 || true
            )
            if [[ -n "${PARSED_MAX}" && "${PARSED_MAX}" -gt "${HIGHEST_TEMP}" ]]; then
                HIGHEST_TEMP="${PARSED_MAX}"
            fi
        fi
    fi

    #
    # 2. Фолбэк на sysfs (/sys/class/thermal/), если sensors недоступен или пуст
    #
    if [[ "${HIGHEST_TEMP}" -eq 0 ]] && compgen -G "/sys/class/thermal/thermal_zone*/temp" > /dev/null; then
        for ZONE_TEMP_FILE in /sys/class/thermal/thermal_zone*/temp; do
            if [[ -r "${ZONE_TEMP_FILE}" ]]; then
                RAW_TEMP=$(cat "${ZONE_TEMP_FILE}" 2>/dev/null || echo 0)
                if [[ "${RAW_TEMP}" =~ ^[0-9]+$ ]] && (( RAW_TEMP > 0 )); then
                    TEMP_C=$(( RAW_TEMP / 1000 ))
                    if (( TEMP_C > HIGHEST_TEMP )); then
                        HIGHEST_TEMP="${TEMP_C}"
                    fi
                fi
            fi
        done
    fi

    # Если температуру извлечь не удалось — завершаем работу без ошибок
    if (( HIGHEST_TEMP == 0 )); then
        exit 0
    fi

    PREV_STATE=""
    if [[ -f "${STATE_FILE}" ]]; then
        PREV_STATE=$(cat "${STATE_FILE}")
    fi

    #
    # Проверка пороговых значений
    #
    if (( HIGHEST_TEMP >= CRITICAL_TEMP )); then
        # Критический перегрев
        if [[ "${PREV_STATE}" != "CRITICAL" ]]; then
            echo "CRITICAL" > "${STATE_FILE}"

            if [[ -f "${NOTIFY_SCRIPT}" ]]; then
                # shellcheck source=/dev/null
                source "${NOTIFY_SCRIPT}"
                notify "temperature" "CRITICAL" "🔥 Критическая температура процессора/системы: ${HIGHEST_TEMP}°C (Порог: ${CRITICAL_TEMP}°C)"
            fi
        fi

    elif (( HIGHEST_TEMP >= WARNING_TEMP )); then
        # Предупредительный перегрев
        if [[ "${PREV_STATE}" != "WARNING" && "${PREV_STATE}" != "CRITICAL" ]]; then
            echo "WARNING" > "${STATE_FILE}"

            if [[ "${NOTIFY_ON_WARNING}" == "true" && -f "${NOTIFY_SCRIPT}" ]]; then
                # shellcheck source=/dev/null
                source "${NOTIFY_SCRIPT}"
                notify "temperature" "WARNING" "⚠️ Высокая температура процессора/системы: ${HIGHEST_TEMP}°C (Порог: ${WARNING_TEMP}°C)"
            fi
        fi

    else
        # Нормализация температуры
        if [[ -n "${PREV_STATE}" ]]; then
            rm -f "${STATE_FILE}"

            if [[ "${NOTIFY_ON_RECOVERY}" == "true" && -f "${NOTIFY_SCRIPT}" ]]; then
                # shellcheck source=/dev/null
                source "${NOTIFY_SCRIPT}"
                notify "temperature" "OK" "✅ Температура процессора/системы нормализовалась: ${HIGHEST_TEMP}°C"
            fi
        fi
    fi

) 200>"${LOCK_FILE}"
