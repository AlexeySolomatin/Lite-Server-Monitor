#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Notification Dispatcher with Anti-Spam (Throttling) & Recovery Logic
# -----------------------------------------------------------------------------

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Подключаем базовые константы, если доступны
if [[ -f "${PROJECT_ROOT}/lib/core/common.sh" ]]; then
    # shellcheck source=/dev/null
    source "${PROJECT_ROOT}/lib/core/common.sh"
fi

# Значения по умолчанию
STATE_DIR="${STATE_DIR:-/var/lib/lsm}/state"
ALERT_COOLDOWN="${ALERT_COOLDOWN:-3600}"

# Загружаем конфигурацию уведомлений
CONFIG_FILE="${NOTIFICATIONS_FILE:-/etc/lsm/notifications.conf}"
if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"
fi

# -----------------------------------------------------------------------------
# Внутренняя функция отправки во все включенные каналы
# -----------------------------------------------------------------------------
dispatch_raw_notification() {
    local subject="$1"
    local message="$2"

    # Отправка в Telegram
    if [[ "${TELEGRAM_ENABLED:-false}" == "true" ]]; then
        if [[ -f "${SCRIPT_DIR}/telegram.sh" ]]; then
            # shellcheck source=/dev/null
            "${SCRIPT_DIR}/telegram.sh" "${subject}" "${message}" || true
        fi
    fi

    # Отправка по Email
    if [[ "${EMAIL_ENABLED:-false}" == "true" ]]; then
        if [[ -f "${SCRIPT_DIR}/email.sh" ]]; then
            # shellcheck source=/dev/null
            "${SCRIPT_DIR}/email.sh" "${subject}" "${message}" || true
        fi
    fi
}

# -----------------------------------------------------------------------------
# Главная функция обработки алертов
# Использование: notify "имя_модуля" "УРОВЕНЬ" "Сообщение"
# Уровень: OK | WARNING | CRITICAL
# -----------------------------------------------------------------------------
notify() {
    local module="${1:-unknown}"
    local level="${2:-CRITICAL}"
    local message="${3:-Детали не указаны.}"
    local hostname
    hostname="$(hostname -f 2>/dev/null || hostname)"

    # Гарантируем наличие директории состояния
    mkdir -p "${STATE_DIR}"
    chmod 750 "${STATE_DIR}" 2>/dev/null || true

    local state_file="${STATE_DIR}/${module}.state"
    local current_time
    current_time="$(date +%s)"

    # --- СЦЕНАРИЙ 1: Состояние нормализовалось (OK) ---
    if [[ "${level}" == "OK" ]]; then
        if [[ -f "${state_file}" ]]; then
            rm -f "${state_file}"
            local subject="🟢 [RECOVERY] [${hostname}] Модуль: ${module}"
            local full_msg="Проблема устранена, статус системы нормализовался.\n\nДетали:\n${message}"
            dispatch_raw_notification "${subject}" "${full_msg}"
        fi
        return 0
    fi

    # --- СЦЕНАРИЙ 2: Обнаружен сбой (WARNING / CRITICAL) ---
    local should_send=true
    local is_escalation=false

    if [[ -f "${state_file}" ]]; then
        local state_data
        state_data="$(cat "${state_file}")"
        local last_sent_time="${state_data%%|*}"
        local last_level="${state_data#*|}"

        local elapsed=$(( current_time - last_sent_time ))

        # Эскалация: Уровень поднялся с WARNING до CRITICAL -> отправляем мгновенно
        if [[ "${last_level}" == "WARNING" && "${level}" == "CRITICAL" ]]; then
            is_escalation=true
            should_send=true
        # Если кулдаун ещё не истёк -> блокируем повторный алерт
        elif (( elapsed < ALERT_COOLDOWN )); then
            should_send=false
        fi
    fi

    # --- Отправка алерта ---
    if [[ "${should_send}" == "true" ]]; then
        echo "${current_time}|${level}" > "${state_file}"

        local icon="🔴"
        [[ "${level}" == "WARNING" ]] && icon="🟡"
        [[ "${is_escalation}" == "true" ]] && icon="🚨 [ЭСКАЛАЦИЯ]"

        local subject="${icon} [${level}] [${hostname}] Модуль: ${module}"
        local full_msg="Обнаружена проблема на сервере ${hostname}.\n\nУровень: ${level}\nМодуль: ${module}\nВремя: $(date '+%Y-%m-%d %H:%M:%S')\n\nДетали:\n${message}"

        dispatch_raw_notification "${subject}" "${full_msg}"
    fi
}

# Вызов при прямом запуске файла из CLI
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    notify "$@"
fi
