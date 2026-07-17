#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# UPS Configuration Screen
# -----------------------------------------------------------------------------

INSTALL_UPS=false
UPS_PROFILE=""

screen_ups() {

    wizard_header

    if ! wizard_yes_no "Install APC UPS support?"; then
        return
    fi

    INSTALL_UPS=true

    echo
    echo "Configuration"
    echo
    echo "1) APC Default"
    echo "2) Configure later"
    echo

    while true; do

        read -rp "Select [1-2]: " answer

        case "${answer}" in

            1)

                UPS_PROFILE="default"

                break
                ;;

            2)

                UPS_PROFILE="later"

                break
                ;;

        esac

    done

}
