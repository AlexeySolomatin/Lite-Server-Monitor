#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Systemd Services Library
# -----------------------------------------------------------------------------

[[ -n "${LSM_SERVICES_LOADED:-}" ]] && return
readonly LSM_SERVICES_LOADED=1

#
# Reload systemd daemon
#
services_daemon_reload() {

    log_info "Reloading systemd daemon..."

    systemctl daemon-reload

}

#
# Check whether unit exists
#
services_exists() {

    local unit="$1"

    systemctl list-unit-files --type=service --type=timer \
        | awk '{print $1}' \
        | grep -Fxq "${unit}"

}

#
# Enable unit
#
services_enable() {

    local unit="$1"

    log_info "Enabling ${unit}"

    systemctl enable "${unit}"

}

#
# Disable unit
#
services_disable() {

    local unit="$1"

    log_info "Disabling ${unit}"

    systemctl disable "${unit}"

}

#
# Start unit
#
services_start() {

    local unit="$1"

    log_info "Starting ${unit}"

    systemctl start "${unit}"

}

#
# Stop unit
#
services_stop() {

    local unit="$1"

    log_info "Stopping ${unit}"

    systemctl stop "${unit}"

}

#
# Restart unit
#
services_restart() {

    local unit="$1"

    log_info "Restarting ${unit}"

    systemctl restart "${unit}"

}

#
# Check whether service is enabled
#
services_is_enabled() {

    local unit="$1"

    systemctl is-enabled "${unit}" >/dev/null 2>&1

}
