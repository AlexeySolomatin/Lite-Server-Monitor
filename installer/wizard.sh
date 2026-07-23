#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Мастер интерактивной установки
# Путь: installer/wizard.sh
# ==============================================================================

set -Eeuo pipefail


#
# Определение корня проекта
#

LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

readonly LSM_SCREENS_DIR="${LSM_ROOT}/installer/screens"


#
# Загрузка экранов мастера
#

load_screen() {

    local screen="${1}"

    if [[ -f "${screen}" ]]; then
        # shellcheck source=/dev/null
        source "${screen}"
    else
        echo "Ошибка: отсутствует экран мастера ${screen}" >&2
        exit 1
    fi

}


#
# Загрузка registry
#

if [[ -f "${LSM_ROOT}/lib/installer/registry.sh" ]]; then

    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/installer/registry.sh"

else

    echo "Ошибка: отсутствует registry.sh" >&2
    exit 1

fi



#
# Загрузка UI экранов
#

load_screen "${LSM_SCREENS_DIR}/common.sh"
load_screen "${LSM_SCREENS_DIR}/welcome.sh"
load_screen "${LSM_SCREENS_DIR}/install_mode.sh"
load_screen "${LSM_SCREENS_DIR}/modules.sh"
load_screen "${LSM_SCREENS_DIR}/notifications.sh"
load_screen "${LSM_SCREENS_DIR}/telegram.sh"
load_screen "${LSM_SCREENS_DIR}/smtp.sh"
load_screen "${LSM_SCREENS_DIR}/ups.sh"
load_screen "${LSM_SCREENS_DIR}/summary.sh"



#
# Стандартный набор установки
#

wizard_default_modules() {

    SELECTED_MODULES=(
        "system"
        "disk"
        "smart"
        "temperature"
        "login"
    )

}



#
# Проверка выбранных модулей
#

wizard_validate_modules() {


    local valid_modules=()

    for module in "${SELECTED_MODULES[@]}"; do

        if registry_exists "${module}"; then

            valid_modules+=("${module}")

        else

            wizard_log_warning \
                "Модуль '${module}' отсутствует в registry и будет пропущен."

        fi

    done


    SELECTED_MODULES=("${valid_modules[@]}")


    if [[ ${#SELECTED_MODULES[@]} -eq 0 ]]; then

        wizard_log_warning \
            "Не выбран ни один модуль. Добавлен системный мониторинг."

        SELECTED_MODULES=("system")

    fi

}



#
# Основной мастер установки
#

run_install_wizard() {


    wizard_init_tty


    screen_welcome


    screen_install_mode



    #
    # Быстрая установка
    #

    if [[ "${INSTALL_MODE:-preset}" == "preset" ]]; then


        wizard_default_modules


    else


        screen_modules


    fi



    wizard_validate_modules



    #
    # Уведомления
    #

    screen_notifications



    if [[ "${NOTIFICATION_METHOD:-none}" == "telegram" ]] || \
       [[ "${NOTIFICATION_METHOD:-none}" == "both" ]]; then

        screen_telegram

    fi



    if [[ "${NOTIFICATION_METHOD:-none}" == "email" ]] || \
       [[ "${NOTIFICATION_METHOD:-none}" == "both" ]]; then

        screen_smtp

    fi



    #
    # UPS
    #

    screen_ups



    #
    # Итог
    #

    screen_summary



    #
    # Экспорт параметров
    #

    export INSTALL_MODE
    export NOTIFICATION_METHOD


    export TG_BOT_TOKEN
    export TG_CHAT_ID


    export EMAIL_ENABLED
    export SMTP_PROFILE
    export SMTP_SERVER
    export SMTP_PORT
    export SMTP_TLS
    export SMTP_USER
    export SMTP_PASS
    export SMTP_FROM
    export ALERT_EMAIL


    export INSTALL_UPS
    export UPS_PROFILE



    #
    # Модули
    #

    export SELECTED_MODULES

    export SELECTED_MODULES_STR="${SELECTED_MODULES[*]}"


}
