#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Fail2Ban Monitor
# -----------------------------------------------------------------------------

set -Eeuo pipefail


#
# Configuration
#

CONFIG_FILE="/etc/lsm/modules/fail2ban.conf"

[[ -f "${CONFIG_FILE}" ]] && source "${CONFIG_FILE}"


#
# Defaults
#

MONITOR_JAILS="${MONITOR_JAILS:-true}"

NOTIFY_ON_BAN="${NOTIFY_ON_BAN:-true}"
NOTIFY_ON_RECOVERY="${NOTIFY_ON_RECOVERY:-true}"


#
# Paths
#

STATE_DIR="/var/lib/lsm/state"

STATE_FILE="${STATE_DIR}/fail2ban_bans"

LOCK_FILE="${STATE_DIR}/fail2ban_check.lock"



(
    #
    # Prevent parallel execution
    #

    flock -n 200 || exit 0



    #
    # Check Fail2Ban availability
    #

    if ! command -v fail2ban-client >/dev/null 2>&1; then
        exit 0
    fi


    #
    # Get active jails
    #

    JAILS=$(
        fail2ban-client status 2>/dev/null |
        grep "Jail list" |
        sed 's/.*Jail list://' |
        tr ',' ' '
    )


    [[ -z "${JAILS}" ]] && exit 0



    CURRENT_BANS=""


    #
    # Check every jail
    #

    for JAIL in ${JAILS}; do


        STATUS=$(
            fail2ban-client status "${JAIL}" 2>/dev/null || true
        )


        BANNED_IPS=$(
            echo "${STATUS}" |
            grep "Banned IP list" |
            sed 's/.*Banned IP list://' |
            xargs
        )


        if [[ -n "${BANNED_IPS}" ]]; then


            while read -r IP; do

                [[ -z "${IP}" ]] && continue

                CURRENT_BANS+="${JAIL}:${IP}"$'\n'


            done <<< "${BANNED_IPS}"


        fi


    done



    #
    # Compare with previous state
    #

    touch "${STATE_FILE}"


    NEW_BANS=$(

        comm -13 \
            <(sort "${STATE_FILE}") \
            <(echo "${CURRENT_BANS}" | sort)

    )


    #
    # New bans
    #

    if [[ -n "${NEW_BANS}" ]]; then


        if [[ "${NOTIFY_ON_BAN}" == "true" ]]; then


            notify_send \
                "Fail2Ban" \
                "🚫 New banned addresses:
${NEW_BANS}" || true


        fi


    fi



    #
    # Recovery
    #

    if [[ "${NOTIFY_ON_RECOVERY}" == "true" ]]; then


        RECOVERED=$(

            comm -23 \
                <(sort "${STATE_FILE}") \
                <(echo "${CURRENT_BANS}" | sort)

        )


        if [[ -n "${RECOVERED}" ]]; then


            notify_send \
                "Fail2Ban" \
                "✅ Ban list changed, previous bans removed:
${RECOVERED}" || true


        fi


    fi



    #
    # Save current state
    #

    echo "${CURRENT_BANS}" |
        sort |
        sed '/^$/d' \
        > "${STATE_FILE}"


) 200>"${LOCK_FILE}"
