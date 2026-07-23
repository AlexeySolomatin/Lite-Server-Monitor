#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Модуль проверки состояния ИБП через apcupsd
# Путь: /opt/lsm/modules/ups/check_ups.sh
# ==============================================================================

set -Eeuo pipefail

# Сброс локали для предсказуемого парсинга вывода
export LC_ALL=C
export LANG=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "${LSM_ROOT:-}" ]]; then
    if [[ -d "${SCRIPT_DIR}/../../lib" ]]; then
        LSM_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
    else
        LSM_ROOT="/opt/lsm"
    fi
fi
export LSM_ROOT

# Подключение базовых библиотек ядра
if [[ -f "${LSM_ROOT}/lib/core/common.sh" ]]; then
    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/core/common.sh"
fi

if [[ -f "${LSM_ROOT}/lib/notifications/notify.sh" ]]; then
    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/notifications/notify.sh"
fi

# Загрузка конфигурации
CONFIG_FILE="/etc/lsm/modules/ups.conf"
if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"
fi

# Настройки по умолчанию с поддержкой обоиx вариантов наименования
BATTERY_WARNING="${BATTERY_WARNING:-${UPS_BATTERY_WARN_THRESHOLD:-50}}"
BATTERY_CRITICAL="${BATTERY_CRITICAL:-${UPS_BATTERY_CRIT_THRESHOLD:-20}}"

NOTIFY_ON_BATTERY="${NOTIFY_ON_BATTERY:-true}"
NOTIFY_ON_LOW_BATTERY="${NOTIFY_ON_LOW_BATTERY:-true}"
NOTIFY_ON_RECOVERY="${NOTIFY_ON_RECOVERY:-true}"

STATE_DIR="/var/lib/lsm/state"
STATE_FILE="${STATE_DIR}/ups_state"
LOCK_FILE="${STATE_DIR}/ups_check.lock"
APCACCESS_BIN="${APCACCESS_BIN:-apcaccess}"

# Проверка наличия утилиты apcaccess
if ! command -v "${APCACCESS_BIN}" &>/dev/null; then
    if declare -f log_info >/dev/null 2>&1; then
        log_info "UPS" "ПРОПУСК: Утилита '${APCACCESS_BIN}' не найдена в системе."
    else
        echo "ПРОПУСК: Утилита '${APCACCESS_BIN}' не найдена в системе (apcupsd не установлен)."
    fi
    exit 0
fi

# Гарантируем наличие директории состояния ДО открытия файла блокировки
mkdir -p "${STATE_DIR}"

(
    # Защита от параллельного запуска
    flock -n 200 || exit 0

    UPS_STATUS=$("${APCACCESS_BIN}" status 2>/dev/null || true)

    if [[ -z "${UPS_STATUS}" ]]; then
        if declare -f log_warn >/dev/null 2>&1; then
            log_warn "UPS" "ПРОПУСК: Служба apcupsd не ответила на запрос status."
        else
            echo "ПРОПУСК: Служба apcupsd не ответила на запрос status."
        fi
        exit 0
    fi

    #
    # Извлечение и очистка параметров
    #
    STATUS_RAW=$(echo "${UPS_STATUS}" | awk -F': ' '/STATUS/ {print $2}' | xargs || true)
    CHARGE_RAW=$(echo "${UPS_STATUS}" | awk -F': ' '/BCHARGE/ {print $2}' | awk '{print $1}' || true)
    TIMELEFT_RAW=$(echo "${UPS_STATUS}" | awk -F': ' '/TIMELEFT/ {print $2}' | xargs || true)

    CHARGE_INT=100
    if [[ -n "${CHARGE_RAW}" ]]; then
        CHARGE_INT="${CHARGE_RAW%.*}"
    fi

    # Валидация чистоты числа перед арифметическими операциями
    if [[ ! "${CHARGE_INT}" =~ ^[0-9]+$ ]]; then
        CHARGE_INT=100
    fi

    #
    # Определение текущего состояния ИБП
    #
    CURRENT_STATE="ONLINE"

    if [[ "${STATUS_RAW}" != *"ONLINE"* ]]; then
        if (( CHARGE_INT <= BATTERY_CRITICAL )); then
            CURRENT_STATE="CRITICAL"
        elif (( CHARGE_INT <= BATTERY_WARNING )); then
            CURRENT_STATE="WARNING"
        else
            CURRENT_STATE="ON_BATTERY"
        fi
    fi

    PREVIOUS_STATE=""
    if [[ -f "${STATE_FILE}" ]]; then
        PREVIOUS_STATE=$(cat "${STATE_FILE}" 2>/dev/null || true)
    fi

    #
    # Обработка смены состояний и отправка уведомлений
    #
    if [[ "${PREVIOUS_STATE}" != "${CURRENT_STATE}" ]]; then
        if declare -f notify >/dev/null 2>&1; then
            local_msg=""

            case "${CURRENT_STATE}" in
                "ON_BATTERY")
                    if [[ "${NOTIFY_ON_BATTERY}" == "true" ]]; then
                        printf -v local_msg "🔋 ИБП перешел на питание от батареи!\n- Заряд: %s%%\n- Осталось времени: %s" \
                            "${CHARGE_RAW:-unknown}" "${TIMELEFT_RAW:-unknown}"
                        notify "ups" "WARNING" "${local_msg}"
                    fi
                    ;;
                "WARNING")
                    if [[ "${NOTIFY_ON_LOW_BATTERY}" == "true" ]]; then
                        printf -v local_msg "⚠️ Низкий уровень заряда ИБП!\n- Заряд: %s%%\n- Осталось времени: %s" \
                            "${CHARGE_RAW:-unknown}" "${TIMELEFT_RAW:-unknown}"
                        notify "ups" "WARNING" "${local_msg}"
                    fi
                    ;;
                "CRITICAL")
                    if [[ "${NOTIFY_ON_LOW_BATTERY}" == "true" ]]; then
                        printf -v local_msg "🚨 Критический уровень заряда ИБП!\n- Заряд: %s%%\n- Осталось времени: %s" \
                            "${CHARGE_RAW:-unknown}" "${TIMELEFT_RAW:-unknown}"
                        notify "ups" "CRITICAL" "${local_msg}"
                    fi
                    ;;
                "ONLINE")
                    if [[ -n "${PREVIOUS_STATE}" && "${NOTIFY_ON_RECOVERY}" == "true" ]]; then
                        notify "ups" "OK" "✅ Питание ИБП восстановлено (Работа от сети)."
                    fi
                    ;;
            esac
        fi

        # Фиксируем актуальное состояние
        echo "${CURRENT_STATE}" > "${STATE_FILE}"
    fi

) 200>"${LOCK_FILE}"
