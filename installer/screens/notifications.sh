#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Notification Configuration Screen
# -----------------------------------------------------------------------------

NOTIFICATION_METHOD="none"

screen_notifications() {

    wizard_header

    echo "Notification method"
    echo
    echo "1) None"
    echo "2) Telegram"
    echo "3) Email"
    echo "4) Telegram + Email"
    echo

    while true; do

        read -rp "Select: " answer

        case "${answer}" in

            1)
                NOTIFICATION_METHOD="none"
                break
                ;;

            2)
                NOTIFICATION_METHOD="telegram"
                break
                ;;

            3)
                NOTIFICATION_METHOD="email"
                break
                ;;

            4)
                NOTIFICATION_METHOD="both"
                break
                ;;

        esac

    done

}
