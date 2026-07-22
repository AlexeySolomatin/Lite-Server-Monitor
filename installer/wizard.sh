#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Installation Wizard
# -----------------------------------------------------------------------------

readonly LSM_SCREENS_DIR="${LSM_ROOT}/installer/screens"

# shellcheck source=/dev/null
source "${LSM_SCREENS_DIR}/common.sh"
# shellcheck source=/dev/null
source "${LSM_SCREENS_DIR}/welcome.sh"
# shellcheck source=/dev/null
source "${LSM_SCREENS_DIR}/install_mode.sh"
# shellcheck source=/dev/null
source "${LSM_SCREENS_DIR}/modules.sh"
# shellcheck source=/dev/null
source "${LSM_SCREENS_DIR}/notifications.sh"
# shellcheck source=/dev/null
source "${LSM_SCREENS_DIR}/smtp.sh"
# shellcheck source=/dev/null
source "${LSM_SCREENS_DIR}/ups.sh"
# shellcheck source=/dev/null
source "${LSM_SCREENS_DIR}/summary.sh"

run_install_wizard() {

    screen_welcome
    screen_install_mode
    screen_modules
    screen_notifications

    if [[ "${NOTIFICATION_METHOD}" == "email" ]] ||
       [[ "${NOTIFICATION_METHOD}" == "both" ]]; then
        screen_smtp
    fi

    if [[ "${INSTALL_UPS}" == "true" ]]; then
        screen_ups
    fi

    screen_summary

}
