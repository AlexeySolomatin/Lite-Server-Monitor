#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Systemd Services Library
# -----------------------------------------------------------------------------

[[ -n "${LSM_SERVICES_LOADED:-}" ]] && return
readonly LSM_SERVICES_LOADED=1

#
# Check if systemd unit exists
#
services_exists() {

    local unit="$1"

    systemctl list-unit-files --no-legend \
        | awk '{print $1}' \
        | grep -Fxq "${unit}"

}

#
# Check if service is enabled
#
services_is_enabled() {

    local unit="$1"

    systemctl is-enabled "${unit}" >/dev/null 2>&1

}

#
# Check if service is active
#
services_is_active() {

    local unit="$1"

    systemctl is-active "${unit}" >/dev/null 2>&1

}

#
# Reload systemd configuration
#
services_daemon_reload() {

    log_info "Reloading systemd daemon..."

    systemctl daemon-reload

}

#
# Enable service
#
services_enable() {

    local unit="$1"

    if services_is_enabled "${unit}"; then
        log_info "Already enabled: ${unit}"
        return 0
    fi

    log_info "Enabling ${unit}"

    systemctl enable "${unit}"

}

#
# Disable service
#
services_disable() {

    local unit="$1"

    if ! services_is_enabled "${unit}"; then
        log_info "Already disabled: ${unit}"
        return 0
    fi

    log_info "Disabling ${unit}"

    systemctl disable "${unit}"

}

#
# Start service
#
services_start() {

    local unit="$1"

    if services_is_active "${unit}"; then
        log_info "Already running: ${unit}"
        return 0
    fi

    log_info "Starting ${unit}"

    systemctl start "${unit}"

}

#
# Stop service
#
services_stop() {

    local unit="$1"

    if ! services_is_active "${unit}"; then
        log_info "Already stopped: ${unit}"
        return 0
    fi

    log_info "Stopping ${unit}"

    systemctl stop "${unit}"

}

#
# Restart service
#
services_restart() {

    local unit="$1"

    log_info "Restarting ${unit}"

    systemctl restart "${unit}"

}

#
# Reload service
#
services_reload() {

    local unit="$1"

    log_info "Reloading ${unit}"

    systemctl reload "${unit}"

}

#
# Enable and start service
#
services_enable_and_start() {

    local unit="$1"

    services_enable "${unit}"
    services_start "${unit}"

}

#
# Stop and disable service
#
services_stop_and_disable() {

    local unit="$1"

    services_stop "${unit}"
    services_disable "${unit}"

}
