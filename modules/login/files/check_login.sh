#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Login Monitor
# -----------------------------------------------------------------------------

set -Eeuo pipefail

# Сброс локали для корректного парсинга дат и сообщений
export LC_ALL=C
export LANG=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

#
# Конфигурация
#

CONFIG_FILE="/etc/lsm/modules/login.conf"
if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"
fi

#
# Значения по умолчанию
#

MONITOR_SSH="${MONITOR_SSH:-true}"
MONITOR_FAILED="${MONITOR_FAILED:-true}"

NOTIFY_ON_LOGIN="${NOTIFY_ON_LOGIN:-true}"
NOTIFY_ON_FAILED="${NOTIFY_ON_FAILED:-true}"

STATE_DIR="/var/lib/lsm/state"
LAST_LOGIN_FILE="${STATE_DIR}/login_last"
LAST_FAILED_FILE="${STATE_DIR}/login_failed_last"
LOCK_FILE="${STATE_DIR}/login_check.lock"
NOTIFY_SCRIPT="${PROJECT_ROOT}/lib/notifications/notify.sh"

# Проверка доступности journalctl
if ! command -v journalctl &>/dev/null; then
    echo "SKIP: Утилита 'journalctl' не найдена в системе."
    exit 0
fi

# Гарантируем наличие директории ДО открытия файла блокировки
mkdir -p "${STATE_DIR}"

(
    # Защита от параллельного запуска
    flock -n 200 || exit 0

    #
    # 1. Мониторинг успешных входов по SSH
    #
    if [[ "${MONITOR_SSH}" == "true" ]]; then
        LOGIN_EVENT=$(
            journalctl \
                -u ssh -u sshd \
                --since "2 minutes ago" \
                --no-pager \
                2>/dev/null |
            grep -E "Accepted (password|publickey)" |
            tail -1 || true
        )

        if [[ -n "${LOGIN_EVENT}" ]]; then
            EVENT_HASH=$(echo "${LOGIN_EVENT}" | sha256sum | awk '{print $1}')
            PREV_HASH=""
            [[ -f "${LAST_LOGIN_FILE}" ]] && PREV_HASH=$(cat "${LAST_LOGIN_FILE}")

            if [[ "${PREV_HASH}" != "${EVENT_HASH}" ]]; then
                echo "${EVENT_HASH}" > "${LAST_LOGIN_FILE}"

                if [[ "${NOTIFY_ON_LOGIN}" == "true" && -f "${NOTIFY_SCRIPT}" ]]; then
                    # shellcheck source=/dev/null
                    source "${NOTIFY_SCRIPT}"

                    USER=$(echo "${LOGIN_EVENT}" | grep -oE "for [^ ]+" | head -1 | awk '{print $2}' || true)
                    IP=$(echo "${LOGIN_EVENT}" | grep -oE "from [0-9a-fA-F:.]+" | head -1 | awk '{print $2}' || true)
                    METHOD=$(echo "${LOGIN_EVENT}" | grep -oE "Accepted (password|publickey)" | awk '{print $2}' || true)

                    notify "login" "INFO" "🔐 Успешный SSH-вход:\n- Пользователь: ${USER:-unknown}\n- IP-адрес: ${IP:-unknown}\n- Метод: ${METHOD:-unknown}"
                fi
            fi
        fi
    fi

    #
    # 2. Мониторинг неудачных попыток входа
    #
    if [[ "${MONITOR_FAILED}" == "true" ]]; then
        FAILED_EVENT=$(
            journalctl \
                -u ssh -u sshd \
                --since "2 minutes ago" \
                --no-pager \
                2>/dev/null |
            grep -E "Failed password|Invalid user" |
            tail -1 || true
        )

        if [[ -n "${FAILED_EVENT}" ]]; then
            EVENT_HASH=$(echo "${FAILED_EVENT}" | sha256sum | awk '{print $1}')
            PREV_HASH=""
            [[ -f "${LAST_FAILED_FILE}" ]] && PREV_HASH=$(cat "${LAST_FAILED_FILE}")

            if [[ "${PREV_HASH}" != "${EVENT_HASH}" ]]; then
                echo "${EVENT_HASH}" > "${LAST_FAILED_FILE}"

                if [[ "${NOTIFY_ON_FAILED}" == "true" && -f "${NOTIFY_SCRIPT}" ]]; then
                    # shellcheck source=/dev/null
                    source "${NOTIFY_SCRIPT}"

                    USER=$(echo "${FAILED_EVENT}" | grep -oE "for (invalid user )?[^ ]+" | awk '{print $NF}' || true)
                    IP=$(echo "${FAILED_EVENT}" | grep -oE "from [0-9a-fA-F:.]+" | head -1 | awk '{print $2}' || true)

                    notify "login" "WARNING" "⚠️ Неудачная попытка SSH-авторизации:\n- Пользователь: ${USER:-unknown}\n- IP-адрес: ${IP:-unknown}"
                fi
            fi
        fi
    fi

) 200>"${LOCK_FILE}"
