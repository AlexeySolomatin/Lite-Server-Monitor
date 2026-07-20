#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# UPS Monitor
# -----------------------------------------------------------------------------

set -Eeuo pipefail


#
# Configuration
#

CONFIG_FILE="/etc/lsm/modules/ups.conf"

[[ -f "${CONFIG_FILE}" ]] && source "${CONFIG_FILE}"


#
# Defaults
#

BATTERY_WARNING="${BATTERY_WARNING:-50}"
BATTERY_CRITICAL="${BATTERY_CRITICAL:-20}"

RUNTIME_WARNING="${RUNTIME_WARNING:-10}"


NOTIFY_ON_BATTERY="${NOTIFY_ON_BATTERY:-true}"
NOTIFY_ON_LOW_BATTERY="${NOTIFY_ON_LOW_BATTERY:-true}"
NOTIFY_ON_RECOVERY="${NOTIFY_ON_RECOVERY:-true}"


#
# Paths
#

STATE_DIR="/var/lib/lsm/state"

STATE_FILE="${STATE_DIR}/ups_state"

LOCK_FILE="${STATE_DIR}/ups_check.lock"



(
    #
    # Prevent parallel execution
    #

    flock -n 200 || exit 0



    #
    # Check apcupsd
    #

    if ! command -v apcaccess >/dev/null 2>&1; then
        exit 0
    fi



    UPS_STATUS=$(

        apcaccess status 2>/dev/null || true

    )


    [[ -z "${UPS_STATUS}" ]] && exit 0



    #
    # Parse values
    #

    STATUS=$(

        echo "${UPS_STATUS}" |
        awk -F': ' '/STATUS/ {print $2}'

    )


    CHARGE=$(

        echo "${UPS_STATUS}" |
        awk -F': ' '/BCHARGE/ {print $2}' |
        tr -d '%'

    )


    TIMELEFT=$(

        echo "${UPS_STATUS}" |
        awk -F': ' '/TIMELEFT/ {print $2}'

    )



    CURRENT_STATE="ONLINE"



    #
    # UPS on battery
    #

    if [[ "${STATUS}" != "ONLINE" ]]; then

        CURRENT_STATE="ON_BATTERY"


        if [[ "${NOTIFY_ON_BATTERY}" == "true" ]]; then


            PREVIOUS_STATE=""

            [[ -f "${STATE_FILE}" ]] &&
                PREVIOUS_STATE=$(cat "${STATE_FILE}")


            if [[ "${PREVIOUS_STATE}" != "${CURRENT_STATE}" ]]; then


                notify_send \
                    "UPS" \
                    "🔋 UPS switched to battery power.
Charge: ${CHARGE}%
Runtime: ${TIMELEFT}" || true


            fi


        fi


    fi



    #
    # Low battery
    #

    if [[ -n "${CHARGE}" ]]; then


        CHARGE_INT=${CHARGE%.*}


        if (( CHARGE_INT <= BATTERY_CRITICAL )); then


            CURRENT_STATE="LOW_BATTERY"


            if [[ "${NOTIFY_ON_LOW_BATTERY}" == "true" ]]; then


                notify_send \
                    "UPS" \
                    "⚠️ UPS battery critical.
Charge: ${CHARGE}%
Runtime: ${TIMELEFT}" || true


            fi


        elif (( CHARGE_INT <= BATTERY_WARNING )); then


            CURRENT_STATE="BATTERY_LOW"


        fi


    fi



    #
    # Recovery
    #

    if [[ -f "${STATE_FILE}" ]]; then


        PREVIOUS_STATE=$(cat "${STATE_FILE}")


        if [[ "${PREVIOUS_STATE}" != "ONLINE" ]] &&
           [[ "${CURRENT_STATE}" == "ONLINE" ]]; then


            if [[ "${NOTIFY_ON_RECOVERY}" == "true" ]]; then


                notify_send \
                    "UPS" \
                    "✅ UPS power restored." || true


            fi


        fi


    fi



    #
    # Save state
    #

    echo "${CURRENT_STATE}" > "${STATE_FILE}"



) 200>"${LOCK_FILE}"
