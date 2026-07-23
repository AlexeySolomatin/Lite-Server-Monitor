#!/usr/bin/env bash
# shellcheck disable=SC2034
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# SMTP Configuration Screen
# -----------------------------------------------------------------------------

EMAIL_ENABLED="false"
SMTP_PROFILE=""
SMTP_SERVER=""
SMTP_PORT=""
SMTP_TLS=""
SMTP_USER=""
SMTP_PASS=""
SMTP_FROM=""
ALERT_EMAIL=""

screen_smtp() {
    wizard_header

    echo "SMTP Email Configuration"
    echo

    read -rp "Enable Email Notifications? [y/N]: " enable_choice
    case "${enable_choice}" in
        [Yy]* )
            EMAIL_ENABLED="true"
            ;;
        * )
            EMAIL_ENABLED="false"
            return 0
            ;;
    esac

    echo
    echo "1) Gmail (port 587, STARTTLS)"
    echo "2) Yandex (port 465, SSL)"
    echo "3) Manual Setup"
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
                read -rp "SMTP Port [587]: " SMTP_PORT
                SMTP_PORT="${SMTP_PORT:-587}"
                read -rp "Use TLS (on/off) [on]: " SMTP_TLS
                SMTP_TLS="${SMTP_TLS:-on}"
                break
                ;;

            *)
                echo "Invalid choice. Please select 1, 2, or 3."
                ;;
        esac
    done

    echo

    read -rp "Username (e.g. lsm-bot@yandex.ru): " SMTP_USER
    read -rsp "Password (App Password): " SMTP_PASS
    echo
    echo

    read -rp "Sender email [${SMTP_USER}]: " SMTP_FROM
    SMTP_FROM="${SMTP_FROM:-$SMTP_USER}"

    read -rp "Recipient email (ALERT_EMAIL): " ALERT_EMAIL
}
