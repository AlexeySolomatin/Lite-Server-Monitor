#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Wizard Common Functions
# -----------------------------------------------------------------------------

wizard_init_tty() {
    if [[ ! -t 0 ]] && [[ -c /dev/tty ]]; then
        exec < /dev/tty
    fi
}

wizard_header() {

    clear

    echo "==============================================================="
    echo "              Lite Server Monitor Installation"
    echo "==============================================================="
    echo

}

wizard_pause() {

    echo
    read -rp "Press Enter to continue..."

}

wizard_yes_no() {

    local prompt="$1"

    while true; do

        read -rp "${prompt} [y/n]: " answer

        case "${answer}" in

            y|Y)
                return 0
                ;;

            n|N)
                return 1
                ;;

        esac

    done

}
