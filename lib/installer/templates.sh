#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Templates Library
# -----------------------------------------------------------------------------

[[ -n "${LSM_TEMPLATES_LOADED:-}" ]] && return
readonly LSM_TEMPLATES_LOADED=1

readonly LSM_TEMPLATE_DIR="${LSM_ROOT}/templates"

#
# Install template
#
templates_install() {

    local template="$1"
    local destination="$2"
    local mode="${3:-644}"
    local owner="${4:-root}"
    local group="${5:-root}"

    local source="${LSM_TEMPLATE_DIR}/${template}"

    if [[ ! -f "${source}" ]]; then
        log_error "Template not found: ${template}"
        return 1
    fi

    deploy_install_file \
        "${source}" \
        "${destination}" \
        "${mode}" \
        "${owner}" \
        "${group}"

}

#
# Check template exists
#
templates_exists() {

    local template="$1"

    [[ -f "${LSM_TEMPLATE_DIR}/${template}" ]]

}

#
# Install only if destination missing
#
templates_install_default() {

    local template="$1"
    local destination="$2"

    [[ -f "${destination}" ]] && return 0

    templates_install "${template}" "${destination}"

}
