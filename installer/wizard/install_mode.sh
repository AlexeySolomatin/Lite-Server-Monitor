#!/usr/bin/env bash

wizard_install_mode() {

    clear

    print_header

    echo "Installation Mode"
    echo
    echo "1) Quick Install (Recommended)"
    echo "2) Custom Install"
    echo "3) Load Configuration File"
    echo "0) Exit"
    echo

    while true; do

        read -rp "Select an option: " choice

        case "$choice" in

            1)
                INSTALL_MODE="quick"
                return
                ;;

            2)
                INSTALL_MODE="custom"
                return
                ;;

            3)
                INSTALL_MODE="config"
                return
                ;;

            0)
                exit 0
                ;;

            *)
                log_warn "Invalid selection."
                ;;

        esac

    done

}
