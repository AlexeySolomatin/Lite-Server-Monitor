#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Диспетчер уведомлений с защитой от спама (Throttling) и логикой восстановления
#
# Путь:
#   lib/notifications/notify.sh
#
# ==============================================================================

set -Eeuo pipefail

# Защита от повторной загрузки при подключении через source
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    [[ -n "${LSM_NOTIFY_LOADED:-}" ]] && return 0
    readonly LSM_NOTIFY_LOADED=1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Подключаем базовые библиотеки, если они доступны
if [[ -f "${PROJECT_ROOT}/lib/core/common.sh" ]]; then
    # shellcheck source=/dev/null
    source "${PROJECT_ROOT}/lib/core/common.sh"
fi

# Значения по умолчанию
STATE_DIR="${STATE_DIR:-/var/lib/lsm/state}"
ALERT_COOLDOWN="${ALERT_COOLDOWN:-3600}"

# Загрузка единого конфигурационного файла LSM
CONFIG_FILE="${LSM_CONFIG:-/etc/lsm/config.conf}"
if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"
elif [[ -f "/etc/lsm/notifications.conf" ]]; then
    # Резервный вариант конфига
    # shellcheck source=/dev/null
    source "/etc/lsm/notifications.conf"
fi

#
# Внутренняя функция отправки во все включенные каналы
#
dispatch_raw_notification() {
    local subject="${1:-}"
    local message="${2:-}"

    if declare -f log_info >/dev/null 2>&1; then
        log_info "NOTIFY" "Отправка уведомления: ${subject}"
    fi

    # Отправка в Telegram
    if [[ "${TELEGRAM_ENABLED:-false}" == "true" ]]; then
        if [[ -f "${SCRIPT_DIR}/telegram.sh" ]]; then
            bash "${SCRIPT_DIR}/telegram.sh" "${subject}" "${message}" || true
        fi
    fi

    # Отправка по Email
    if [[ "${EMAIL_ENABLED:-false}" == "true" ]]; then
        if [[ -f "${SCRIPT_DIR}/email.sh" ]]; then
            bash "${SCRIPT_DIR}/email.sh" "${subject}" "${message}" || true
        fi
    fi
}

#
# Главная функция обработки алертов
# Использование: notify "имя_модуля" "УРОВЕНЬ" "Сообщение"
# Уровень: OK | WARNING | CRITICAL
#
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
            local full_msg
            printf -v full_msg "Проблема устранена, статус системы нормализовался.\n\nДетали:\n%s" "${message}"
            dispatch_raw_notification "${subject}" "${full_msg}"
        fi
        return 0
    fi

    # --- СЦЕНАРИЙ 2: Обнаружен сбой (WARNING / CRITICAL) ---
    local should_send=true
    local is_escalation=false

    if [[ -f "${state_file}" ]]; then
        local state_data
        state_data="$(cat "${state_file}" 2>/dev/null || echo "")"
        local last_sent_time="${state_data%%|*}"
        local last_level="${state_data#*|}"

        # Проверка корректности метки времени
        if [[ ! "${last_sent_time}" =~ ^[0-9]+$ ]]; then
            last_sent_time=0
        fi

        local elapsed=$(( current_time - last_sent_time ))

        # Эскалация: Уровень поднялся с WARNING до CRITICAL -> отправляем мгновенно
        if [[ "${last_level}" == "WARNING" && "${level}" == "CRITICAL" ]]; then
            is_escalation=true
            should_send=true
        # Если кулдаун ещё не истёк -> блокируем повторный алерт
        elif (( elapsed < ALERT_COOLDOWN )); then
            should_send=false
            if declare -f log_debug >/dev/null 2>&1; then
                log_debug "NOTIFY" "Алерт заблокирован кулдауном (${elapsed}s < ${ALERT_COOLDOWN}s) для модуля ${module}"
            fi
        fi
    fi

    # --- Отправка алерта ---
    if [[ "${should_send}" == "true" ]]; then
        echo "${current_time}|${level}" > "${state_file}"

        local icon="🔴"
        [[ "${level}" == "WARNING" ]] && icon="🟡"
        [[ "${is_escalation}" == "true" ]] && icon="🚨 [ЭСКАЛАЦИЯ]"

        local subject="${icon} [${level}] [${hostname}] Модуль: ${module}"
        local full_msg
        printf -v full_msg "Обнаружена проблема на сервере %s.\n\nУровень: %s\nМодуль: %s\nВремя: %s\n\nДетали:\n%s" \
            "${hostname}" "${level}" "${module}" "$(date '+%Y-%m-%d %H:%M:%S')" "${message}"

        dispatch_raw_notification "${subject}" "${full_msg}"
    fi
}

#
# Прямая отправка информационного сообщения.
#
# Использование: notify_info "имя_модуля" "Сообщение"
#
# В отличие от notify() НЕ использует throttle-state
# и не создает state-файл. Предназначена для событий,
# не являющихся авариями (например, успешный вход по SSH).
#

notify_info() {
    local module="${1:-unknown}"
    local message="${2:-}"
    local hostname
    hostname="$(hostname -f 2>/dev/null || hostname)"

    local subject="🔵 [INFO] [${hostname}] Модуль: ${module}"

    dispatch_raw_notification "${subject}" "${message}"
}

#
# Прямая отправка готового сообщения без обработки состояния.
#
# Использование: notify_raw "Тема" "Сообщение"
#
# Применяется для контента, который должен доставляться
# всегда независимо от кулдаунов (например, ежедневный отчет).
#

notify_raw() {
    local subject="${1:-Уведомление LSM}"
    local message="${2:-}"

    dispatch_raw_notification "${subject}" "${message}"
}

# Вызов при прямом запуске файла из CLI
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    notify "$@"
fi
