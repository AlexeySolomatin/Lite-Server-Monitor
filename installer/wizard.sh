#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Главный мастер установки
# Путь: installer/wizard.sh
# ==============================================================================


set -Eeuo pipefail


LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

readonly SCREEN_DIR="${LSM_ROOT}/installer/screens"


load_screen() {

    local file="$1"

    if [[ -f "${file}" ]]; then
        # shellcheck source=/dev/null
        source "${file}"
    else
        log_error "Не найден экран мастера: ${file}"
        exit 1
    fi

}


load_screens() {

    local screens=(
        common.sh
        welcome.sh
        install_mode.sh
        modules.sh
        notifications.sh
        telegram.sh
        smtp.sh
        ups.sh
        summary.sh
    )


    for screen in "${screens[@]}"; do
        load_screen "${SCREEN_DIR}/${screen}"
    done

}


wizard_defaults() {


    INSTALL_MODE="preset"

    NOTIFICATION_METHOD="none"

    SELECTED_MODULES=(
        system
        disk
        smart
        temperature
    )


}


run_install_wizard() {


    wizard_defaults

    load_screens


    wizard_init_tty


    screen_welcome

    screen_install_mode


    case "${INSTALL_MODE}" in

        preset)

            SELECTED_MODULES=(
                system
                disk
                smart
                temperature
                login
            )

        ;;


        custom)

            screen_modules

        ;;


    esac


    screen_notifications


    if [[ "${NOTIFICATION_METHOD}" == "telegram" ||
          "${NOTIFICATION_METHOD}" == "both" ]]; then

        screen_telegram

    fi



    if [[ "${NOTIFICATION_METHOD}" == "email" ||
          "${NOTIFICATION_METHOD}" == "both" ]]; then

        screen_smtp

    fi


    screen_ups


    screen_summary


    export INSTALL_MODE
    export NOTIFICATION_METHOD
    export SELECTED_MODULES

    export SELECTED_MODULES_STR="${SELECTED_MODULES[*]}"

}
