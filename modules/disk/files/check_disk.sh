#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Disk Monitor
# -----------------------------------------------------------------------------

set -Eeuo pipefail

#
# Configuration
#

CONFIG_FILE="/etc/lsm/modules/disk.conf"

[[ -f "${CONFIG_FILE}" ]] && source "${CONFIG_FILE}"

STATE_DIR="/var/lib/lsm/state"

STATE_FILE="${STATE_DIR}/disk_alert"

LOCK_FILE="${STATE_DIR}/disk_check.lock"

mkdir -p "${STATE_DIR}"

#
# Default values
#

WARNING="${WARNING:-80}"

IGNORE_MOUNTS="${IGNORE_MOUNTS:-}"

(
    flock -n 200 || exit 0

    ALERT_TRIGGERED=0
    ALERT_MSG=""

    while IFS= read -r line; do
        ALERT_TRIGGERED=1
        ALERT_MSG="${ALERT_MSG} ${line}"
    done < <(

        df -P | awk \
            -v max="${WARNING}" \
            -v ignore="${IGNORE_MOUNTS}" '

        BEGIN{
            split(ignore,a," ")
            for(i in a)
                skip[a[i]]=1
        }

        NR>1 {

            if(skip[$6])
                next

            if($1 ~ /(tmpfs|loop|cdrom)/)
                next

            gsub(/%/,"",$5)

            if($5>=max)
                printf "%s=%s%%\n",$6,$5

        }'

    )

    if [[ "${ALERT_TRIGGERED}" -eq 1 ]]; then

        if [[ ! -f "${STATE_FILE}" ]]; then

            touch "${STATE_FILE}"

            notify_send \
                "DISK" \
                "❌ Disk usage exceeded:${ALERT_MSG}" || true

        fi

    else

        if [[ -f "${STATE_FILE}" ]]; then

            rm -f "${STATE_FILE}"

            notify_send \
                "DISK" \
                "✅ Disk usage returned to normal." || true

        fi

    fi

) 200>"${LOCK_FILE}"
