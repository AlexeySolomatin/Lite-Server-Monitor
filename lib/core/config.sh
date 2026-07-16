#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Configuration library
# -----------------------------------------------------------------------------

[[ -n "${LSM_CONFIG_LOADED:-}" ]] && return
readonly LSM_CONFIG_LOADED=1

#
# Load configuration
#
load_config() {

    if [[ ! -f "${CONFIG_FILE}" ]]; then
        log_error "Configuration file not found:"
        log_error "  ${CONFIG_FILE}"
        return 1
    fi

    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"
}

#
# Check configuration
#
config_exists() {

    [[ -f "${CONFIG_FILE}" ]]

}

#
# Validate configuration
#
validate_config() {

    local errors=0

    if [[ -z "${LSM_HOSTNAME:-}" ]]; then
        log_error "LSM_HOSTNAME is not configured."
        ((errors++))
    fi

    if [[ -z "${REPORT_TIME:-}" ]]; then
        log_error "REPORT_TIME is not configured."
        ((errors++))
    fi

    return "${errors}"
}

#
# Create configuration directory
#
create_config_dir() {

    ensure_directory "${CONFIG_DIR}"

    chmod 750 "${CONFIG_DIR}"

}

#
# Install default configuration
#
install_default_config() {

    if config_exists; then
        log_info "Configuration already exists."
        return
    fi

    cp \
        "${TEMPLATES_DIR}/config.conf" \
        "${CONFIG_FILE}"

    chmod 640 "${CONFIG_FILE}"

    log_success "Default configuration installed."

}
