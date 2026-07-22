#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Module Manager
# -----------------------------------------------------------------------------

[[ -n "${LSM_MODULES_LOADED:-}" ]] && return
readonly LSM_MODULES_LOADED=1

readonly LSM_MODULES_DIR="${LSM_ROOT}/modules"

#
# Check module exists
#
modules_exists() {

    local module="$1"

    [[ -d "${LSM_MODULES_DIR}/${module}" ]]

}

#
# List available modules
#
modules_list() {

    find "${LSM_MODULES_DIR}" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -printf "%f\n" \
        | sort

}

#
# Install module
#
modules_install() {

    local module="$1"

    if ! modules_exists "${module}"; then
        log_error "Unknown module: ${module}"
        return 1
    fi

    log_info "Installing module: ${module}"

    local module_dir="${LSM_MODULES_DIR}/${module}"

    if [[ -f "${module_dir}/manifest.conf" ]]; then
        # shellcheck source=/dev/null
        source "${module_dir}/manifest.conf"
    fi

    if [[ -x "${module_dir}/install.sh" ]]; then
        "${module_dir}/install.sh"
    fi

}

#
# Remove module
#
modules_remove() {

    local module="$1"

    local module_dir="${LSM_MODULES_DIR}/${module}"

    if [[ -x "${module_dir}/uninstall.sh" ]]; then
        "${module_dir}/uninstall.sh"
    fi

}

#
# Enable module
#
modules_enable() {

    local module="$1"

    local module_dir="${LSM_MODULES_DIR}/${module}"

    if [[ -x "${module_dir}/enable.sh" ]]; then
        "${module_dir}/enable.sh"
    fi

}

#
# Disable module
#
modules_disable() {

    local module="$1"

    local module_dir="${LSM_MODULES_DIR}/${module}"

    if [[ -x "${module_dir}/disable.sh" ]]; then
        "${module_dir}/disable.sh"
    fi

}
