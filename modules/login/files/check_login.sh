#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Login Monitor
# -----------------------------------------------------------------------------

set -Eeuo pipefail


#
# Configuration
#

CONFIG_FILE="/etc/lsm/modules/login.conf"

[[ -f "${CONFIG_FILE}" ]] && source "${CONFIG_FILE}"


#
# Defaults
#

MONITOR_SSH="${MONITOR_SSH:-true}"
MONITOR_FAILED="${MONITOR_FAILED:-true}"

NOTIFY_ON_LOGIN="${NOTIFY_ON_LOGIN:-true}"
NOTIFY_ON_FAILED="${NOTIFY_ON_FAILED:-true}"


#
# Paths
#

STATE_DIR="/var/lib/lsm/state"

LAST_LOGIN_FILE="${STATE_DIR}/login_last"

LAST_FAILED_FILE="${STATE_DIR}/login_failed_last"

LOCK_FILE="${STATE_DIR}/login_check.lock"



(
    #
    # Prevent parallel execution
    #

    flock -n 200 || exit 0



    #
    # SSH successful login detection
    #

    if [[ "${MONITOR_SSH}" == "true" ]]; then


        LOGIN_EVENT=$(

            journalctl \
                -u ssh \
                --since "2 minutes ago" \
                --no-pager \
                2>/dev/null |
            grep -E "Accepted (password|publickey)" |
            tail -1

        )


        if [[ -n "${LOGIN_EVENT}" ]]; then


            EVENT_HASH=$(echo "${LOGIN_EVENT}" | sha256sum | awk '{print $1}')


            if [[ ! -f "${LAST_LOGIN_FILE}" ]] ||
               [[ "$(cat "${LAST_LOGIN_FILE}")" != "${EVENT_HASH}" ]]; then


                echo "${EVENT_HASH}" > "${LAST_LOGIN_FILE}"


                if [[ "${NOTIFY_ON_LOGIN}" == "true" ]]; then


                    USER=$(

                        echo "${LOGIN_EVENT}" |
                        grep -oE "for [^ ]+" |
                        awk '{print $2}'

                    )


                    IP=$(

                        echo "${LOGIN_EVENT}" |
                        grep -oE "from [0-9a-fA-F:.]+" |
                        awk '{print $2}'

                    )


                    notify_send \
                        "Login" \
                        "🔐 SSH login: user=${USER:-unknown} source=${IP:-unknown}" || true


                fi

            fi

        fi

    fi



    #
    # Failed login detection
    #

    if [[ "${MONITOR_FAILED}" == "true" ]]; then


        FAILED_EVENT=$(

            journalctl \
                -u ssh \
                --since "2 minutes ago" \
                --no-pager \
                2>/dev/null |
            grep -E "Failed password|Invalid user" |
            tail -1

        )


        if [[ -n "${FAILED_EVENT}" ]]; then


            EVENT_HASH=$(echo "${FAILED_EVENT}" | sha256sum | awk '{print $1}')


            if [[ ! -f "${LAST_FAILED_FILE}" ]] ||
               [[ "$(cat "${LAST_FAILED_FILE}")" != "${EVENT_HASH}" ]]; then


                echo "${EVENT_HASH}" > "${LAST_FAILED_FILE}"


                if [[ "${NOTIFY_ON_FAILED}" == "true" ]]; then


                    IP=$(

                        echo "${FAILED_EVENT}" |
                        grep -oE "from [0-9a-fA-F:.]+" |
                        awk '{print $2}'

                    )


                    notify_send \
                        "Login" \
                        "⚠️ Failed SSH login attempt from ${IP:-unknown}" || true


                fi


            fi


        fi


    fi



) 200>"${LOCK_FILE}"
