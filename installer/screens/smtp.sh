#!/usr/bin/env bash
# shellcheck disable=SC2034
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# SMTP Configuration Screen
# -----------------------------------------------------------------------------

SMTP_PROFILE=""
SMTP_SERVER=""
SMTP_PORT=""
SMTP_TLS=""
SMTP_USERNAME=""
SMTP_PASSWORD=""
SMTP_FROM=""

screen_smtp() {

    wizard_header

    echo "SMTP Configuration"
    echo
    echo "1) Gmail"
    echo "2) Yandex"
    echo "3) Manual"
    echo

    while true; do

        read -rp "Select profile [1-3]: " answer

        case "${answer}" in

            1)

                SMTP_PROFILE="gmail"
                SMTP_SERVER="smtp.gmail.com"
                SMTP_PORT="587"
                SMTP_TLS="on"

                break
                ;;

            2)

                SMTP_PROFILE="yandex"
                SMTP_SERVER="smtp.yandex.ru"
                SMTP_PORT="465"
                SMTP_TLS="on"

                break
                ;;

            3)

                SMTP_PROFILE="manual"

                read -rp "SMTP Server: " SMTP_SERVER
                read -rp "SMTP Port: " SMTP_PORT
                read -rp "Use TLS (on/off): " SMTP_TLS

                break
                ;;

        esac

    done

    echo

    read -rp "Username: " SMTP_USERNAME

    read -rsp "Password (Application Password): " SMTP_PASSWORD

    echo

    read -rp "Sender email: " SMTP_FROM

}
