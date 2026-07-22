#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Notification Dispatcher
# -----------------------------------------------------------------------------

[[ -n "${LSM_NOTIFY_LOADED:-}" ]] && return
readonly LSM_NOTIFY_LOADED=1


NOTIFY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


# shellcheck source=/dev/null
source "${NOTIFY_DIR}/telegram.sh"

# shellcheck source=/dev/null
source "${NOTIFY_DIR}/email.sh"



notify_send()
{

    local title="$1"
    local message="$2"


    if [[ "${NOTIFY_TELEGRAM:-false}" == "true" ]]; then

        "${NOTIFY_DIR}/telegram.sh" \
            "${title}" \
            "${message}"

    fi



    if [[ "${NOTIFY_EMAIL:-false}" == "true" ]]; then

        "${NOTIFY_DIR}/email.sh" \
            "${title}" \
            "${message}"

    fi

}
