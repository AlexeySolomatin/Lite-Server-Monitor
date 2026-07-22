#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Installation Summary
# -----------------------------------------------------------------------------

screen_summary() {

    wizard_header

    echo "Installation Summary"
    echo
    echo "Mode            : ${INSTALL_MODE}"
    echo "Notifications   : ${NOTIFICATION_METHOD}"
    echo "SMTP Profile    : ${SMTP_PROFILE:-none}"
    echo "UPS             : ${UPS_PROFILE:-disabled}"
    echo

    echo "Modules"

    for module in "${SELECTED_MODULES[@]}"; do
        echo "  • ${module}"
    done

    echo

    if ! wizard_yes_no "Start installation?"; then
        echo
        log_warn "Installation cancelled."
        exit 0
    fi

}
