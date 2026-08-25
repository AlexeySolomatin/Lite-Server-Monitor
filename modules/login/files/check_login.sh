#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Модуль контроля входов пользователей
#
# Путь:
#   modules/login/files/check_login.sh
#
# Назначение:
#   Мониторинг активности входов по SSH через журнал journald:
#
#       - успешные входы (Accepted password / Accepted publickey);
#       - неудачные попытки (Failed password / Invalid user).
#
#   В режиме check анализируется окно журнала за 2 минуты. Обрабатываются
#   ВСЕ строки окна; дедупликация выполняется по хэшам событий в файле
#   /var/lib/lsm/state/login_seen (записи старше ~10 минут вычищаются,
#   т.к. окно журнала — 2 минуты с запасом на сдвиг запусков).
#
#   Уведомления отправляются через централизованный диспетчер LSM:
#
#       - успешные входы  → notify_info "login" "<сообщение>"
#         (информационное сообщение БЕЗ alert-семантики, без throttle-state);
#       - неудачные попытки → notify "login" "WARNING" "<сообщение>"
#         (с защитой от спама через кулдаун ALERT_COOLDOWN).
#
# Режимы:
#
#   check_login.sh status
#       Краткий статус: события за окно 2 минуты,
#       число успешных/неудачных. Всегда возвращает exit 0.
#
#   check_login.sh report
#       Сводка за сутки: успешные входы, неудачные попытки,
#       последние события. Состояние не изменяет.
#       Всегда возвращает exit 0.
#
#   check_login.sh check
#       Машинная проверка с уведомлениями.
#       Коды выхода: 0 = OK, 1 = WARNING (неудачные попытки),
#       2 = CRITICAL/ошибка окружения.
#
# ==============================================================================

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
SEEN_FILE="${STATE_DIR}/login_seen"
LOCK_FILE="${STATE_DIR}/login_check.lock"

# TTL записей дедупликации: окно journalctl 2 минуты × запас
SEEN_TTL=600

CHECK_WINDOW="2 minutes ago"
REPORT_WINDOW="24 hours ago"

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
# Строки журнала ssh/sshd с успешными входами за указанный период.
#

login_accepted_events()
{
    local since="${1:-${CHECK_WINDOW}}"

    journalctl \
        -u ssh -u sshd \
        --since "${since}" \
        --no-pager \
        2>/dev/null |
    grep -E "Accepted (password|publickey)" || true
}


#
# Строки журнала ssh/sshd с неудачными попытками входа.
#

login_failed_events()
{
    local since="${1:-${CHECK_WINDOW}}"

    journalctl \
        -u ssh -u sshd \
        --since "${since}" \
        --no-pager \
        2>/dev/null |
    grep -E "Failed password|Invalid user" || true
}


#
# Разбор полей события.
#

event_user()
{
    printf '%s' "$1" | grep -oE "for [^ ]+" | head -1 | awk '{print $2}' || true
}

event_ip()
{
    printf '%s' "$1" | grep -oE "from [0-9a-fA-F:.]+" | head -1 | awk '{print $2}' || true
}

event_method()
{
    printf '%s' "$1" | grep -oE "Accepted (password|publickey)" | head -1 | awk '{print $2}' || true
}

event_failed_user()
{
    printf '%s' "$1" | grep -oE "for (invalid user )?[^ ]+" | head -1 | awk '{print $NF}' || true
}


#
# Метка времени события из строки журнала ("Mon DD HH:MM:SS").
#

event_time()
{
    printf '%s' "$1" | awk '{print $1, $2, $3}'
}


#
# Хэш строки события.
#

event_hash()
{
    printf '%s' "$1" | sha256sum | awk '{print $1}'
}


#
# Дедупликация обработанных событий.
#
# Файл SEEN_FILE содержит записи вида "<epoch>:<hash>".
# Перед каждой проверкой вычищаются записи старше SEEN_TTL секунд:
# окно журнала — 2 минуты, запас защищает от сдвига запусков таймера.
#

seen_prune()
{
    local now cutoff

    now="$(date +%s)"
    cutoff=$(( now - SEEN_TTL ))

    touch "${SEEN_FILE}"

    if awk -F':' -v cutoff="${cutoff}" \
           '$1 ~ /^[0-9]+$/ && $1 >= cutoff' \
           "${SEEN_FILE}" > "${SEEN_FILE}.tmp"; then
        mv "${SEEN_FILE}.tmp" "${SEEN_FILE}"
    else
        rm -f "${SEEN_FILE}.tmp"
    fi
}

seen_has()
{
    grep -qF -- "$1" "${SEEN_FILE}" 2>/dev/null
}

seen_add()
{
    printf '%s:%s\n' "$(date +%s)" "$1" >> "${SEEN_FILE}"
}


# ==============================================================================
# Краткий статус
# ==============================================================================

do_status()
{
    local acc_count=0
    local fail_count=0

    acc_count="$(login_accepted_events | wc -l | tr -d ' ')"
    fail_count="$(login_failed_events | wc -l | tr -d ' ')"

    printf 'Login: за последние 2 минуты — успешных входов: %d, неудачных попыток: %d\n' \
        "${acc_count}" "${fail_count}"

    printf 'Мониторинг успешных входов : %s\n' \
        "$([[ "${MONITOR_SSH}" == "true" ]] && echo включен || echo отключен)"

    printf 'Мониторинг неудачных попыток: %s\n' \
        "$([[ "${MONITOR_FAILED}" == "true" ]] && echo включен || echo отключен)"


    local recent=""
    recent="$(
        {
            login_accepted_events
            login_failed_events
        } | tail -n 5 || true
    )"

    if [[ -n "${recent}" ]]; then

        printf '\nПоследние события:\n'

        while IFS= read -r line; do
            [[ -z "${line}" ]] && continue
            printf '  %s\n' "${line}"
        done <<< "${recent}"

    fi


    #
    # Статус — информационный режим, всегда успешный код выхода.
    #

    return 0
}


# ==============================================================================
# Сводка за сутки (без изменения состояния)
# ==============================================================================

do_report()
{
    local acc_count=0
    local fail_count=0

    acc_count="$(login_accepted_events "${REPORT_WINDOW}" | wc -l | tr -d ' ')"
    fail_count="$(login_failed_events "${REPORT_WINDOW}" | wc -l | tr -d ' ')"

    printf '================================================================\n'

    printf 'Отчет по входам пользователей за последние 24 часа\n'

    printf '================================================================\n'

    printf '\nУспешные входы     : %d\n' "${acc_count}"

    printf 'Неудачные попытки  : %d\n' "${fail_count}"


    local line
    local shown=0

    printf '\nПоследние успешные входы (до 10):\n'

    printf '%s\n' \
        "------------------------------------------------------------"

    shown=0
    while IFS= read -r line; do

        [[ -z "${line}" ]] && continue

        if (( shown >= 10 )); then
            break
        fi
        shown=$((shown + 1))

        printf '  [%s] %s@%s (%s)\n' \
            "$(event_time "${line}")" \
            "$(event_user "${line}")" \
            "$(event_ip "${line}")" \
            "$(event_method "${line}")"

    done < <(login_accepted_events "${REPORT_WINDOW}")

    if (( shown == 0 )); then
        printf '  нет событий\n'
    fi


    printf '\nПоследние неудачные попытки (до 10):\n'

    printf '%s\n' \
        "------------------------------------------------------------"

    shown=0
    while IFS= read -r line; do

        [[ -z "${line}" ]] && continue

        if (( shown >= 10 )); then
            break
        fi
        shown=$((shown + 1))

        printf '  [%s] пользователь: %s, IP: %s\n' \
            "$(event_time "${line}")" \
            "$(event_failed_user "${line}")" \
            "$(event_ip "${line}")"

    done < <(login_failed_events "${REPORT_WINDOW}")

    if (( shown == 0 )); then
        printf '  нет событий\n'
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
    # Каталог состояния должен существовать ДО захвата блокировки.
    #

    mkdir -p "${STATE_DIR}"


    #
    # Защита от параллельного запуска.
    #

    exec 200>"${LOCK_FILE}"

    if ! flock -n 200; then

        log_info "LOGIN" "Пропуск: предыдущая проверка выполняется."

        exit 0

    fi


    #
    # Вычистка устаревших записей дедупликации.
    #

    seen_prune


    local event_line hash user ip method
    local failed_count=0
    local login_count=0


    #
    # 1. Успешные входы по SSH.
    #
    # Обрабатываются ВСЕ строки окна за запуск (не только последняя):
    # каждое событие дедуплицируется по хэшу в SEEN_FILE.
    #

    if [[ "${MONITOR_SSH}" == "true" ]]; then

        while IFS= read -r event_line; do

            [[ -z "${event_line}" ]] && continue

            hash="$(event_hash "${event_line}")"

            if seen_has "${hash}"; then
                continue
            fi

            seen_add "${hash}"

            user="$(event_user "${event_line}")"
            ip="$(event_ip "${event_line}")"
            method="$(event_method "${event_line}")"

            login_count=$((login_count + 1))

            log_info "LOGIN" "Успешный SSH-вход: пользователь ${user:-unknown}, IP ${ip:-unknown}, метод ${method:-unknown}."

            #
            # Информационное событие без alert-семантики:
            # notify_info отправляет сразу и не создает throttle-state.
            #

            if [[ "${NOTIFY_ON_LOGIN}" == "true" ]] &&
               declare -F notify_info >/dev/null 2>&1; then

                notify_info "login" \
                    "🔐 Успешный SSH-вход:\n- Пользователь: ${user:-unknown}\n- IP-адрес: ${ip:-unknown}\n- Метод: ${method:-unknown}"

            fi

        done < <(login_accepted_events)

    fi


    #
    # 2. Неудачные попытки входа.
    #

    if [[ "${MONITOR_FAILED}" == "true" ]]; then

        while IFS= read -r event_line; do

            [[ -z "${event_line}" ]] && continue

            hash="$(event_hash "${event_line}")"

            if seen_has "${hash}"; then
                continue
            fi

            seen_add "${hash}"

            user="$(event_failed_user "${event_line}")"
            ip="$(event_ip "${event_line}")"

            failed_count=$((failed_count + 1))

            log_warn "LOGIN" "Неудачная попытка SSH-авторизации: пользователь ${user:-unknown}, IP ${ip:-unknown}."

            #
            # Алерт с защитой от спама: повторные WARNING гасятся
            # кулдауном ALERT_COOLDOWN внутри notify (state: login.state).
            #

            if [[ "${NOTIFY_ON_FAILED}" == "true" ]] &&
               declare -F notify >/dev/null 2>&1; then

                notify "login" "WARNING" \
                    "⚠️ Неудачная попытка SSH-авторизации:\n- Пользователь: ${user:-unknown}\n- IP-адрес: ${ip:-unknown}"

            fi

        done < <(login_failed_events)

    fi


    if (( login_count > 0 )) || (( failed_count > 0 )); then

        log_info "LOGIN" "Обработано событий за окно 2 минуты: успешных входов ${login_count}, неудачных попыток ${failed_count}."

    fi


    #
    # Module API: неудачные попытки — проблемное состояние (WARNING).
    #

    if (( failed_count > 0 )); then
        return 1
    fi

    return 0
}


# ==============================================================================
# Диспетчер режимов Module API
# ==============================================================================

main()
{
    #
    # Проверка доступности journalctl.
    #

    if ! command -v journalctl >/dev/null 2>&1; then
        log_info "LOGIN" "Пропуск: утилита 'journalctl' не найдена в системе."
        return 0
    fi


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
