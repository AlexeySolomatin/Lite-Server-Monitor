#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Package Management Library
# -----------------------------------------------------------------------------

[[ -n "${LSM_PACKAGES_LOADED:-}" ]] && return
readonly LSM_PACKAGES_LOADED=1

APT_UPDATED=false

#
# Execute apt-get command
#
run_apt() {

    DEBIAN_FRONTEND=noninteractive \
        apt-get \
        -y \
        "$@"

}

#
# Update package cache (only once)
#
update_package_cache() {

    if [[ "${APT_UPDATED}" == "true" ]]; then
        return 0
    fi

    log_info "Updating package index..."

    run_apt update

    APT_UPDATED=true

}

#
# Check whether package is installed
#
package_installed() {

    dpkg-query -W -f='${Status}' "$1" 2>/dev/null |
        grep -q "install ok installed"

}

#
# Install one package
#
install_package() {

    local package="$1"

    if package_installed "${package}"; then
        log_info "Package already installed: ${package}"
        return 0
    fi

    log_info "Installing package: ${package}"

    run_apt install "${package}"

}
