#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Модуль мониторинга Fail2Ban
#
# Путь:
#   modules/fail2ban/files/check_fail2ban.sh
#
# Назначение:
#   Отслеживание банов IP-адресов в Fail2Ban по принципу diff:
#   текущий список забаненных IP ("jail:IP") сравнивается с предыдущим,
#   сохраненным в кэше /var/lib/lsm/state/fail2ban_bans.
#
#   Уведомления отправляются через централизованный диспетчер LSM:
#
#       - CRITICAL — демон Fail2Ban не отвечает;
#       - WARNING  — новые баны IP-адресов;
#       - OK       — разблокировка IP после ранее отправленного алерта
#                    (отправляется только если алерт был).
#
#   Опция MONITOR_JAILS позволяет обрабатывать только выбранные jail
#   (по умолчанию — все).
#
# Режимы:
#
#   check_fail2ban.sh status
#       Краткий статус: демон активен, число jail.
#       Всегда возвращает exit 0.
#
#   check_fail2ban.sh report
#       Таблица jail с числом забаненных IP (сейчас / всего).
#       Состояние не изменяет, уведомления не отправляет.
#       Всегда возвращает exit 0.
#
#   check_fail2ban.sh check
#       Машинная проверка с уведомлениями (diff-баны).
#       Коды выхода: 0 = OK, 1 = WARNING (новые баны),
#       2 = CRITICAL/ошибка окружения.
#
# ==============================================================================

set -Eeuo pipefail

# Сброс локали для корректного парсинга вывода fail2ban-client
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

# Пустая строка или "all" — мониторить все jail.
# Иначе — список jail через запятую, например: "sshd,nginx-badbot"
MONITOR_JAILS="${MONITOR_JAILS:-}"

NOTIFY_ON_BAN="${NOTIFY_ON_BAN:-true}"
NOTIFY_ON_RECOVERY="${NOTIFY_ON_RECOVERY:-true}"

STATE_DIR="/var/lib/lsm/state"
BANS_CACHE="${STATE_DIR}/fail2ban_bans"
LOCK_FILE="${STATE_DIR}/fail2ban_check.lock"

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
# Демон Fail2Ban отвечает на запросы.
#

f2b_daemon_alive()
{
    fail2ban-client ping >/dev/null 2>&1
}


#
# Список активных jail (разделитель — пробел/запятая в исходном выводе,
# здесь нормализуется к пробелам).
#

f2b_list_jails()
{
    fail2ban-client status 2>/dev/null |
        grep "Jail list" |
        sed 's/.*Jail list://' |
        tr ',' ' ' || true
}


#
# Проверка, входит ли jail в список MONITOR_JAILS.
#
# Пустой MONITOR_JAILS или значение "all" означают обработку всех jail.
#

jail_selected()
{
    local jail="${1}"
    local normalized
    local entry
    local entry_lower
    local jail_lower

    normalized="$(printf '%s' "${MONITOR_JAILS}" | tr -d ' ' | tr '[:upper:]' '[:lower:]')"

    if [[ -z "${normalized}" || "${normalized}" == "all" ]]; then
        return 0
    fi

    jail_lower="$(printf '%s' "${jail}" | tr '[:upper:]' '[:lower:]')"

    while IFS= read -r entry; do
        entry_lower="$(printf '%s' "${entry}" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')"
        [[ -z "${entry_lower}" ]] && continue
        if [[ "${entry_lower}" == "${jail_lower}" ]]; then
            return 0
        fi
    done < <(printf '%s' "${normalized}" | tr ',' '\n')

    return 1
}


#
# Список забаненных IP конкретного jail (через пробел).
#
# Разбор выполняется по строке "Banned IP list" из статуса jail;
# xargs нормализует пробелы и пустые значения.
#

f2b_banned_ips()
{
    local jail="${1}"

    fail2ban-client status "${jail}" 2>/dev/null |
        grep "Banned IP list" |
        sed 's/.*Banned IP list://' |
        xargs || true
}


#
# Форматирование пар "jail:IP" в маркированный список.
#

format_pairs()
{
    local data="${1:-}"

    if [[ -z "${data}" ]]; then
        return 0
    fi

    printf -- "- %s\n" "${data//$'\n'/$'\n'- }"
}


# ==============================================================================
# Краткий статус
# ==============================================================================

do_status()
{
    if ! f2b_daemon_alive; then

        printf 'Fail2ban: демон не запущен или сокет не отвечает\n'

        return 0

    fi


    local jails
    jails="$(f2b_list_jails)"

    local count=0
    read -r -a JAIL_ARRAY <<< "${jails}"
    count=${#JAIL_ARRAY[@]}

    printf 'Fail2ban: активен, jail: %d\n' "${count}"

    if [[ -n "$(printf '%s' "${jails}" | tr -d '[:space:]')" ]]; then
        printf 'Jail list: %s\n' "${jails}"
    fi


    #
    # Статус — информационный режим, всегда успешный код выхода.
    #

    return 0
}


# ==============================================================================
# Отчет по jail (без изменения состояния)
# ==============================================================================

do_report()
{
    printf '================================================================\n'

    printf 'Отчет Fail2Ban\n'

    printf '================================================================\n'


    if ! f2b_daemon_alive; then

        printf '\nДемон Fail2Ban не запущен или сокет не отвечает.\n\n'

        return 0

    fi


    local jails
    jails="$(f2b_list_jails)"

    if [[ -z "$(printf '%s' "${jails}" | tr -d '[:space:]')" ]]; then

        printf '\nАктивные jail не обнаружены.\n\n'

        return 0

    fi


    printf '\n%-24s %18s %14s\n' \
        "Джейл" \
        "Сейчас в бане" \
        "Всего банов"

    printf '%s\n' \
        "------------------------------------------------------------"

    local jail
    local status_output
    local cur_banned
    local tot_banned
    local total_cur=0
    local selected=0

    for jail in ${jails}; do

        jail_selected "${jail}" || continue
        selected=$((selected + 1))

        status_output="$(fail2ban-client status "${jail}" 2>/dev/null || true)"

        cur_banned="$(
            printf '%s\n' "${status_output}" |
            awk -F':' '/Currently banned/ {gsub(/[[:space:]]/, "", $2); print $2 + 0; exit}'
        )"
        [[ -n "${cur_banned}" ]] || cur_banned="н/д"

        tot_banned="$(
            printf '%s\n' "${status_output}" |
            awk -F':' '/Total banned/ {gsub(/[[:space:]]/, "", $2); print $2 + 0; exit}'
        )"
        [[ -n "${tot_banned}" ]] || tot_banned="н/д"

        if [[ "${cur_banned}" =~ ^[0-9]+$ ]]; then
            total_cur=$((total_cur + cur_banned))
        fi

        printf '%-24s %18s %14s\n' "${jail}" "${cur_banned}" "${tot_banned}"

    done

    if (( selected == 0 )); then

        printf '\nНи один jail не выбран (проверьте MONITOR_JAILS).\n\n'

        return 0

    fi

    printf '%s\n' \
        "------------------------------------------------------------"

    printf '%-24s %18d %14s\n' "Итого (сейчас)" "${total_cur}" "-"

    printf '\n'


    #
    # Отчет не отправляет уведомления и всегда успешен.
    #

    return 0
}


# ==============================================================================
# Машинная проверка с уведомлениями (diff-баны)
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

        log_info "FAIL2BAN" "Пропуск: предыдущая проверка выполняется."

        exit 0

    fi


    #
    # Демон должен отвечать.
    #

    if ! f2b_daemon_alive; then

        log_error "FAIL2BAN" "Сервис Fail2Ban не запущен или сокет не отвечает."

        if declare -F notify >/dev/null 2>&1; then
            notify "fail2ban" "CRITICAL" "❌ Сервис Fail2Ban не запущен или сокет не отвечает!"
        fi

        return 2

    fi


    #
    # Получение списка активных jail.
    #

    local jails
    jails="$(f2b_list_jails)"

    if [[ -z "$(printf '%s' "${jails}" | tr -d '[:space:]')" ]]; then

        log_info "FAIL2BAN" "Активные jail не обнаружены."

        printf '%s' "" > "${BANS_CACHE}"

        return 0

    fi


    #
    # Сбор заблокированных IP только по выбранным jail.
    #

    local current_bans=""
    local jail
    local banned_ips
    local ip

    for jail in ${jails}; do

        jail_selected "${jail}" || continue

        banned_ips="$(f2b_banned_ips "${jail}")"

        if [[ -n "${banned_ips}" ]]; then
            for ip in ${banned_ips}; do
                [[ -z "${ip}" ]] && continue
                current_bans+="${jail}:${ip}"$'\n'
            done
        fi

    done


    #
    # Diff текущего списка банов с сохраненным состоянием.
    #

    touch "${BANS_CACHE}"

    local sorted_current sorted_previous new_bans recovered

    sorted_current="$(
        printf '%s' "${current_bans}" |
        grep -v '^$' | sort -u || true
    )"

    sorted_previous="$(
        sort -u "${BANS_CACHE}" 2>/dev/null |
        grep -v '^$' || true
    )"

    # Поиск новых банов
    new_bans="$(comm -13 <(printf '%s\n' "${sorted_previous}") <(printf '%s\n' "${sorted_current}") || true)"

    # Поиск разблокированных IP
    recovered="$(comm -23 <(printf '%s\n' "${sorted_previous}") <(printf '%s\n' "${sorted_current}") || true)"


    #
    # Уведомления через центральный диспетчер.
    #

    local result=0

    if [[ -n "${new_bans}" ]]; then

        log_warn "FAIL2BAN" "Зафиксирована новая блокировка IP-адресов: $(printf '%s' "${new_bans}" | tr '\n' ' ')"

        if [[ "${NOTIFY_ON_BAN}" == "true" ]] && declare -F notify >/dev/null 2>&1; then
            notify "fail2ban" "WARNING" "🚫 Зафиксирована новая блокировка IP-адресов:\n$(format_pairs "${new_bans}")"
        fi

        result=1

    fi

    if [[ -n "${recovered}" ]]; then

        log_success "FAIL2BAN" "Разблокированы IP-адреса: $(printf '%s' "${recovered}" | tr '\n' ' ')"

        if [[ "${NOTIFY_ON_RECOVERY}" == "true" ]] && declare -F notify >/dev/null 2>&1; then
            notify "fail2ban" "OK" "✅ Разблокированы IP-адреса (истёк срок бана):\n$(format_pairs "${recovered}")"
        fi

    fi


    #
    # Сохраняем текущий список банов как новое состояние.
    #

    printf '%s\n' "${sorted_current}" > "${BANS_CACHE}"


    #
    # Module API: ненулевой код означает проблемное состояние.
    #

    return "${result}"
}


# ==============================================================================
# Проверки окружения
# ==============================================================================

ensure_environment()
{
    if ! command -v fail2ban-client >/dev/null 2>&1; then
        log_info "FAIL2BAN" "Пропуск: утилита 'fail2ban-client' не найдена в системе (Fail2Ban не установлен)."
        exit 0
    fi

    if [[ "${EUID}" -ne 0 ]]; then
        log_info "FAIL2BAN" "Пропуск: для работы с Fail2Ban требуются права root."
        exit 0
    fi
}

# ==============================================================================
# Диспетчер режимов Module API
# ==============================================================================

main()
{
    ensure_environment

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
