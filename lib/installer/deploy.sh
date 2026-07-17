#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Deployment Library
# -----------------------------------------------------------------------------

[[ -n "${LSM_DEPLOY_LOADED:-}" ]] && return
readonly LSM_DEPLOY_LOADED=1

#
# Create directory
#
deploy_create_directory() {

    local directory="$1"
    local mode="${2:-755}"
    local owner="${3:-root}"
    local group="${4:-root}"

    if [[ ! -d "${directory}" ]]; then
        log_info "Creating directory: ${directory}"
        mkdir -p "${directory}"
    fi

    chmod "${mode}" "${directory}"
    chown "${owner}:${group}" "${directory}"
}

#
# Install file
#
deploy_install_file() {

    local source="$1"
    local destination="$2"
    local mode="${3:-644}"
    local owner="${4:-root}"
    local group="${5:-root}"

    if [[ ! -f "${source}" ]]; then
        log_error "File not found: ${source}"
        return 1
    fi

    install \
        -D \
        -m "${mode}" \
        -o "${owner}" \
        -g "${group}" \
        "${source}" \
        "${destination}"

    log_success "Installed: ${destination}"
}

#
# Install directory
#
deploy_install_directory() {

    local source="$1"
    local destination="$2"

    if [[ ! -d "${source}" ]]; then
        log_error "Directory not found: ${source}"
        return 1
    fi

    mkdir -p "${destination}"
    cp -a "${source}/." "${destination}/"

    log_success "Installed directory: ${destination}"
}

#
# Backup file
#
deploy_backup_file() {

    local file="$1"

    [[ -f "${file}" ]] || return 0

    cp -a "${file}" "${file}.bak"

    log_info "Backup created: ${file}.bak"
}

#
# Remove file
#
deploy_remove_file() {

    local file="$1"

    [[ -f "${file}" ]] || return 0

    rm -f "${file}"

    log_info "Removed: ${file}"
}

#
# Remove directory
#
deploy_remove_directory() {

    local directory="$1"

    [[ -d "${directory}" ]] || return 0

    rm -rf "${directory}"

    log_info "Removed directory: ${directory}"
}

#
# Create symbolic link
#
deploy_create_symlink() {

    local source="$1"
    local destination="$2"

    ln -sfn "${source}" "${destination}"

    log_info "Created symlink: ${destination}"
}
