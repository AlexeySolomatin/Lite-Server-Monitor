#!/usr/bin/env bash

wizard_notifications() {

    clear

    print_header

    echo "Notification Method"
    echo
    echo "1) Telegram"
    echo "2) Email"
    echo "3) Telegram + Email"
    echo "4) No notifications"
    echo

    while true; do

        read -rp "Select an option: " choice

        case "$choice" in

            1)
                INSTALL_CONFIG[notifications]="telegram"
                return
                ;;

            2)
                INSTALL_CONFIG[notifications]="email"
                return
                ;;

            3)
                INSTALL_CONFIG[notifications]="both"
                return
                ;;

            4)
                INSTALL_CONFIG[notifications]="none"
                return
                ;;

            *)
                log_warn "Invalid selection."
                ;;

        esac

    done

}
