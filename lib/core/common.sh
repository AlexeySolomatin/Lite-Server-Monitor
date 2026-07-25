#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Базовое окружение и общие системные переменные
# Путь: lib/core/common.sh
# ==============================================================================

set -Eeuo pipefail


[[ -n "${LSM_COMMON_LOADED:-}" ]] && return 0
readonly LSM_COMMON_LOADED=1



#
# Root проекта
#

if [[ -z "${LSM_ROOT:-}" ]]; then

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    LSM_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

fi


export LSM_ROOT
export PROJECT_ROOT="${LSM_ROOT}"



#
# Project metadata
#

export PROJECT_NAME="Lite Server Monitor"


if [[ -f "${LSM_ROOT}/VERSION" ]]; then

    PROJECT_VERSION="$(tr -d '\r\n' < "${LSM_ROOT}/VERSION")"

else

    PROJECT_VERSION="unknown"

fi


export PROJECT_VERSION



#
# System paths
#

export LSM_CONFIG_DIR="${LSM_CONFIG_DIR:-/etc/lsm}"
export LSM_LOG_DIR="${LSM_LOG_DIR:-/var/log/lsm}"
export LSM_DATA_DIR="${LSM_DATA_DIR:-/var/lib/lsm}"



#
# Helpers
#


is_root()
{
    [[ "${EUID:-$(id -u)}" -eq 0 ]]
}



check_root()
{

    if ! is_root; then

        if declare -f log_error >/dev/null 2>&1; then

            log_error \
                "SYSTEM" \
                "Скрипт должен быть запущен с правами root."

        else

            echo \
                "Ошибка: требуется root." >&2

        fi

        exit 1

    fi

}



command_exists()
{
    command -v "$1" >/dev/null 2>&1
}



is_supported_os()
{

    [[ -f /etc/os-release ]] || return 1


    # shellcheck disable=SC1091
    source /etc/os-release


    case "${ID:-}" in

        debian|ubuntu|linuxmint|pop)

            return 0

            ;;

    esac


    [[ "${ID_LIKE:-}" == *debian* ]]

}



has_internet()
{

    ping \
        -c 1 \
        -W 2 \
        1.1.1.1 \
        >/dev/null 2>&1 \
    ||
    ping \
        -c 1 \
        -W 2 \
        8.8.8.8 \
        >/dev/null 2>&1

}
