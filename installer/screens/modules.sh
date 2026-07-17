#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Module Selection Screen
# -----------------------------------------------------------------------------

SELECTED_MODULES=()

screen_modules() {

    wizard_header

    echo "Modules"
    echo

    if wizard_yes_no "Install Disk Monitor?"; then
        SELECTED_MODULES+=("disk")
    fi

    if wizard_yes_no "Install SMART Monitor?"; then
        SELECTED_MODULES+=("smart")
    fi

    if wizard_yes_no "Install RAID Monitor?"; then
        SELECTED_MODULES+=("raid")
    fi

    if wizard_yes_no "Install Temperature Monitor?"; then
        SELECTED_MODULES+=("temperature")
    fi

    if wizard_yes_no "Install Login Monitor?"; then
        SELECTED_MODULES+=("login")
    fi

    if wizard_yes_no "Install Fail2Ban Monitor?"; then
        SELECTED_MODULES+=("fail2ban")
    fi

}
