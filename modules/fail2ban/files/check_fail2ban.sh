#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Fail2Ban Monitor
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

CONFIG_FILE="/etc/lsm/modules/fail2ban.conf"
if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"
fi

#
# Значения по умолчанию
#

MONITOR_JAILS="${MONITOR_JAILS:-true}"
NOTIFY_ON_BAN="${NOTIFY_ON_BAN:-true}"
NOTIFY_ON_RECOVERY="${NOTIFY_ON_RECOVERY:-true}"

STATE_DIR="/var/lib/lsm/state"
STATE_FILE="${STATE_DIR}/fail2ban_bans"
LOCK_FILE="${STATE_DIR}/fail2ban_check.lock"
NOTIFY_SCRIPT="${PROJECT_ROOT}/lib/notifications/notify.sh"

#
# Проверки окружения
#

if ! command -v fail2ban-client &>/dev/null; then
    echo "SKIP: Утилита 'fail2ban-client' не найдена в системе."
    exit 0
fi

if [[ "${EUID}" -ne 0 ]]; then
    echo "SKIP: Для работы с Fail2Ban требуются права root."
    exit 0
fi

# Гарантируем наличие директории ДО открытия файла блокировки
mkdir -p "${STATE_DIR}"

(
    # Защита от параллельного запуска
    flock -n 200 || exit 0

    # Проверка отзывчивости демона fail2ban
    if ! fail2ban-client ping &>/dev/null; then
        if [[ -f "${NOTIFY_SCRIPT}" ]]; then
            # shellcheck source=/dev/null
            source "${NOTIFY_SCRIPT}"
            notify "fail2ban" "CRITICAL" "Сервис Fail2Ban не запущен или сокет не отвечает!"
        fi
        exit 0
    fi

    #
    # Получение списка активных джейлов
    #
    JAILS=$(
        fail2ban-client status 2>/dev/null |
        grep "Jail list" |
        sed 's/.*Jail list://' |
        tr ',' ' ' || true
    )

    if [[ -z "${JAILS}" ]]; then
        exit 0
    fi

    CURRENT_BANS=""

    #
    # Сбор заблокированных IP по всем джейлам
    #
    for JAIL in ${JAILS}; do
        STATUS=$(fail2ban-client status "${JAIL}" 2>/dev/null || true)

        BANNED_IPS=$(
            echo "${STATUS}" |
            grep "Banned IP list" |
            sed 's/.*Banned IP list://' |
            xargs || true
        )

        if [[ -n "${BANNED_IPS}" ]]; then
            for IP in ${BANNED_IPS}; do
                [[ -z "${IP}" ]] && continue
                CURRENT_BANS+="${JAIL}:${IP}"$'\n'
            done
        fi
    done

    # Подготавливаем отсортированные данные без пустых строк
    SORTED_CURRENT=$(echo -n "${CURRENT_BANS}" | grep -v '^$' | sort -u || true)

    touch "${STATE_FILE}"
    SORTED_PREVIOUS=$(sort -u "${STATE_FILE}" | grep -v '^$' || true)

    # Поиск новых банов
    NEW_BANS=$(comm -13 <(echo "${SORTED_PREVIOUS}") <(echo "${SORTED_CURRENT}") || true)

    # Поиск разблокированных IP
    RECOVERED=$(comm -23 <(echo "${SORTED_PREVIOUS}") <(echo "${SORTED_CURRENT}") || true)

    #
    # Уведомления через центральный диспетчер
    #
    if [[ -f "${NOTIFY_SCRIPT}" ]]; then
        # shellcheck source=/dev/null
        source "${NOTIFY_SCRIPT}"

        if [[ -n "${NEW_BANS}" && "${NOTIFY_ON_BAN}" == "true" ]]; then
            if [[ -n "${NEW_BANS:-}" ]]; then
                FORMATTED_NEW="- ${NEW_BANS//$'\n'/$'\n- '}"
            else
                FORMATTED_NEW=""
            fi
            notify "fail2ban" "WARNING" "Зафиксирована новая блокировка IP-адресов:\n${FORMATTED_NEW}"
        fi

        if [[ -n "${RECOVERED}" && "${NOTIFY_ON_RECOVERY}" == "true" ]]; then
            if [[ -n "${RECOVERED:-}" ]]; then
                FORMATTED_REC="- ${RECOVERED//$'\n'/$'\n- '}"
            else
                FORMATTED_REC=""
            fi
            notify "fail2ban" "OK" "Разблокированы IP-адреса (истёк срок бана):\n${FORMATTED_REC}"
        fi
    fi

    # Сохраняем текущий список банов
    echo "${SORTED_CURRENT}" > "${STATE_FILE}"

) 200>"${LOCK_FILE}"
