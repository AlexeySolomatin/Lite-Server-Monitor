#!/usr/bin/env bash

wizard_smtp() {

    local notifications="${INSTALL_CONFIG[notifications]}"

    if [[ "${notifications}" != "email" && \
          "${notifications}" != "both" ]]; then
        return
    fi

    clear

    print_header

    echo "Email Provider"
    echo
    echo "1) Gmail"
    echo "2) Yandex"
    echo "3) Mail.ru"
    echo "4) Office365"
    echo "5) Custom SMTP"
    echo

    while true; do

        read -rp "Select an option: " choice

        case "$choice" in

            1)
                INSTALL_CONFIG[smtp_provider]="gmail"
                return
                ;;

            2)
                INSTALL_CONFIG[smtp_provider]="yandex"
                return
                ;;

            3)
                INSTALL_CONFIG[smtp_provider]="mailru"
                return
                ;;

            4)
                INSTALL_CONFIG[smtp_provider]="office365"
                return
                ;;

            5)
                INSTALL_CONFIG[smtp_provider]="custom"
                return
                ;;

            *)
                log_warn "Invalid selection."
                ;;

        esac

    done

}
