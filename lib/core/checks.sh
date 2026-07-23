#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Библиотека проверки окружения и системных требований
# ==============================================================================

set -Eeuo pipefail

# Защита от повторного подключения файла
[[ -n "${LSM_CHECKS_LOADED:-}" ]] && return 0
readonly LSM_CHECKS_LOADED=1

#
# Проверка прав суперпользователя (root)
#
is_root() {
    [[ "${EUID:-$(id -u)}" -eq 0 ]]
}

require_root() {
    if ! is_root; then
        if declare -f log_error >/dev/null 2>&1; then
            log_error "CHECKS" "Для выполнения этой команды требуются права root (или sudo)."
        else
            echo "Ошибка: Для выполнения этой команды требуются права root." >&2
        fi
        exit 1
    fi
}

#
# Проверка наличия утилит в $PATH
#
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

require_command() {
    local cmd="$1"

    if ! command_exists "${cmd}"; then
        if declare -f log_error >/dev/null 2>&1; then
            log_error "CHECKS" "Не найдена обязательная системная утилита: ${cmd}"
        else
            echo "Ошибка: Не найдена обязательная системная утилита: ${cmd}" >&2
        fi
        exit 1
    fi
}

#
# Определение и проверка операционной системы
#
get_os_id() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        echo "${ID:-unknown}"
    else
        echo "unknown"
    fi
}

get_os_version() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        echo "${VERSION_ID:-unknown}"
    else
        echo "unknown"
    fi
}

is_supported_os() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        case "${ID:-}" in
            debian|ubuntu|linuxmint|pop)
                return 0
                ;;
            *)
                if [[ "${ID_LIKE:-}" == *"debian"* || "${ID_LIKE:-}" == *"ubuntu"* ]]; then
                    return 0
                fi
                return 1
                ;;
        esac
    fi
    return 1
}

require_supported_os() {
    if ! is_supported_os; then
        local current_os
        current_os="$(get_os_id)"
        if declare -f log_error >/dev/null 2>&1; then
            log_error "CHECKS" "Неподдерживаемая операционная система: ${current_os}. Поддерживаются системы семейства Debian/Ubuntu."
        else
            echo "Ошибка: Неподдерживаемая операционная система: ${current_os}." >&2
        fi
        exit 1
    fi
}

#
# Проверка сетевого подключения
#
has_internet() {
    ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1 || ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1
}

#
# Проверка прав на запись в директорию
#
is_writable_dir() {
    local target_dir="$1"
    [[ -d "${target_dir}" && -w "${target_dir}" ]]
}

#
# Проверка наличия конфигурационного файла
#
config_exists() {
    local cfg="${CONFIG_FILE:-${LSM_CONFIG_DIR:-/etc/lsm}/config.conf}"
    [[ -f "${cfg}" ]]
}
