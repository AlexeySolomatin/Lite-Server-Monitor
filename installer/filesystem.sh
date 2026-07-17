#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Filesystem Management Library
# -----------------------------------------------------------------------------

[[ -n "${LSM_FILESYSTEM_LOADED:-}" ]] && return
readonly LSM_FILESYSTEM_LOADED=1

#
# Create directory if it does not exist
#
ensure_directory() {

    local dir="$1"
    local mode="${2:-755}"
    local owner="${3:-root}"
    local group="${4:-root}"

    if [[ ! -d "${dir}" ]]; then
        log_info "Creating directory: ${dir}"
        mkdir -p "${dir}"
    fi

    chmod "${mode}" "${dir}"
    chown "${owner}:${group}" "${dir}"
}

#
# Remove directory
#
remove_directory() {

    local dir="$1"

    if [[ -d "${dir}" ]]; then
        log_info "Removing directory: ${dir}"
        rm -rf "${dir}"
    fi
}

#
# Install file
#
install_file() {

    local source="$1"
    local destination="$2"
    local mode="${3:-644}"
    local owner="${4:-root}"
    local group="${5:-root}"

    if [[ ! -f "${source}" ]]; then
        log_error "Source file not found: ${source}"
        return 1
    fi

    install \
        -D \
        -m "${mode}" \
        -o "${owner}" \
        -g "${group}" \
        "${source}" \
        "${destination}"
}

#
# Copy directory recursively
#
copy_directory() {

    local source="$1"
    local destination="$2"

    if [[ ! -d "${source}" ]]; then
        log_error "Directory not found: ${source}"
        return 1
    fi

    cp -a "${source}" "${destination}"
}

#
# Backup existing file
#
backup_file() {

    local file="$1"

    [[ -f "${file}" ]] || return 0

    local backup="${file}.bak.$(date +%Y%m%d%H%M%S)"

    log_info "Creating backup: ${backup}"

    cp -a "${file}" "${backup}"
}

#
# Restore backup
#
restore_backup() {

    local backup="$1"
    local target="$2"

    [[ -f "${backup}" ]] || return 1

    cp -a "${backup}" "${target}"
}

#
# Create symbolic link
#
create_symlink() {

    local source="$1"
    local target="$2"

    ln -sfn "${source}" "${target}"
}
