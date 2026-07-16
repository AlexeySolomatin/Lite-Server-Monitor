#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Utility Library
# -----------------------------------------------------------------------------

[[ -n "${LSM_UTILS_LOADED:-}" ]] && return
readonly LSM_UTILS_LOADED=1

#
# Current timestamp
#
current_timestamp() {

    date '+%Y-%m-%d %H:%M:%S'

}

#
# Trim whitespace
#
trim() {

    local value="$*"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    printf '%s' "${value}"

}

#
# Generate random string
#
random_string() {

    local length="${1:-16}"

    tr -dc 'A-Za-z0-9' </dev/urandom | head -c "${length}"

}
