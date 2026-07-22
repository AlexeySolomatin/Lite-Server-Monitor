#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Environment validation library
# -----------------------------------------------------------------------------

[[ -n "${LSM_CHECKS_LOADED:-}" ]] && return
readonly LSM_CHECKS_LOADED=1

#
# Check if running as root
#
is_root() {
    [[ "${EUID}" -eq 0 ]]
}

require_root() {
    if ! is_root; then
        log_error "This command must be run as root."
        exit 1
    fi
}

#
# Check command availability
#
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

require_command() {
    local cmd="$1"

    if ! command_exists "${cmd}"; then
        log_error "Required command not found: ${cmd}"
        exit 1
    fi
}

#
# Check operating system
#
get_os_id() {
    # shellcheck source=/dev/null
    source /etc/os-release
    echo "${ID}"
}

get_os_version() {
    # shellcheck source=/dev/null
    source /etc/os-release
    echo "${VERSION_ID}"
}

is_supported_os() {

    local os
    os="$(get_os_id)"

    case "${os}" in
        ubuntu|debian)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

require_supported_os() {

    if ! is_supported_os; then
        log_error "Unsupported operating system."
        exit 1
    fi

}

#
# Check internet connectivity
#
has_internet() {

    ping -c1 -W2 8.8.8.8 >/dev/null 2>&1

}

#
# Check write permissions
#
is_writable_dir() {

    [[ -w "$1" ]]

}

#
# Check configuration
#
config_exists() {

    [[ -f "${CONFIG_FILE}" ]]

}
