#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Filesystem helper library
# -----------------------------------------------------------------------------

[[ -n "${LSM_FILESYSTEM_LOADED:-}" ]] && return
readonly LSM_FILESYSTEM_LOADED=1

file_exists() {
    [[ -f "$1" ]]
}

dir_exists() {
    [[ -d "$1" ]]
}

ensure_directory() {
    local dir="$1"

    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
    fi
}

ensure_parent_directory() {
    mkdir -p "$(dirname "$1")"
}

safe_copy() {
    local source="$1"
    local destination="$2"

    ensure_parent_directory "$destination"
    cp "$source" "$destination"
}

safe_move() {
    local source="$1"
    local destination="$2"

    ensure_parent_directory "$destination"
    mv "$source" "$destination"
}

safe_remove() {
    local target="$1"

    [[ -e "$target" ]] && rm -rf "$target"
}

set_owner() {
    chown "$1":"$2" "$3"
}

set_permissions() {
    chmod "$1" "$2"
}
