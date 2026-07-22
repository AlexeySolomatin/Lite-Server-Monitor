#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Core Common Variables & Base Environment
# -----------------------------------------------------------------------------

set -Eeuo pipefail

# Автоопределение корневого каталога проекта, если он еще не передан
if [[ -z "${LSM_ROOT:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # На два уровня вверх из lib/core -> корень проекта
    LSM_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
fi

export LSM_ROOT
export PROJECT_ROOT="${LSM_ROOT}"
export PROJECT_NAME="Lite Server Monitor"
export PROJECT_VERSION="1.0.0"

# Пути к основным директориям системы
export LSM_CONFIG_DIR="${LSM_CONFIG_DIR:-/etc/lsm}"
export LSM_LOG_DIR="${LSM_LOG_DIR:-/var/log/lsm}"
export LSM_DATA_DIR="${LSM_DATA_DIR:-/var/lib/lsm}"

# Проверка выполнения от имени root
check_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        if declare -f log_error >/dev/null 2>&1; then
            log_error "This script must be run as root (or with sudo)."
        else
            echo "Error: This script must be run as root." >&2
        fi
        exit 1
    fi
}
