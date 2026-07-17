#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Permissions Library
# -----------------------------------------------------------------------------

[[ -n "${LSM_PERMISSIONS_LOADED:-}" ]] && return
readonly LSM_PERMISSIONS_LOADED=1

#
# Set owner and permissions
#
permissions_set() {

    local path="$1"
    local mode="$2"
    local owner="${3:-root}"
    local group="${4:-root}"

    [[ -e "${path}" ]] || return 1

    chmod "${mode}" "${path}"
    chown "${owner}:${group}" "${path}"
}

#
# Fix configuration directory
#
permissions_config() {

    permissions_set "/etc/lsm" 750 root root

    find /etc/lsm -type d -exec chmod 750 {} \;
    find /etc/lsm -type f -exec chmod 640 {} \;

}

#
# Fix log directory
#
permissions_logs() {

    permissions_set "/var/log/lsm" 750 root root

    find /var/log/lsm -type d -exec chmod 750 {} \;
    find /var/log/lsm -type f -exec chmod 640 {} \;

}

#
# Fix runtime directory
#
permissions_runtime() {

    permissions_set "/var/lib/lsm" 750 root root

    find /var/lib/lsm -type d -exec chmod 750 {} \;
    find /var/lib/lsm -type f -exec chmod 640 {} \;

}

#
# Apply all permissions
#
permissions_fix_all() {

    log_info "Applying permissions..."

    permissions_config
    permissions_logs
    permissions_runtime

}
