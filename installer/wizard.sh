#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Мастер интерактивной установки
#
# Путь:
#   installer/wizard.sh
#
# Назначение:
#   Управляет последовательностью экранов установки LSM.
#
# Режимы:
#
#   standard:
#       - установка всех зарегистрированных модулей;
#       - включение стандартной конфигурации;
#       - включение мониторинга ИБП;
#       - настройка только уведомлений.
#
#   custom:
#       - выбор модулей;
#       - выбор каналов уведомлений;
#       - настройка дополнительных параметров.
# ==============================================================================


set -Eeuo pipefail



#
# Корень проекта
#

LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

readonly LSM_SCREENS_DIR="${LSM_ROOT}/installer/screens"



#
# Загрузка экрана мастера
#

load_screen()
{
    local screen="${1}"


    if [[ -f "${screen}" ]]; then

        # shellcheck source=/dev/null
        source "${screen}"

    else

        echo "Ошибка: отсутствует экран установки: ${screen}" >&2
        exit 1

    fi
}



#
# Загрузка registry модулей
#

if [[ -f "${LSM_ROOT}/lib/installer/registry.sh" ]]; then

    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/installer/registry.sh"

else

    echo "Ошибка: отсутствует lib/installer/registry.sh" >&2
    exit 1

fi



#
# Загрузка экранов мастера
#

load_screen "${LSM_SCREENS_DIR}/common.sh"
load_screen "${LSM_SCREENS_DIR}/welcome.sh"
load_screen "${LSM_SCREENS_DIR}/install_mode.sh"
load_screen "${LSM_SCREENS_DIR}/modules.sh"
load_screen "${LSM_SCREENS_DIR}/notifications.sh"
load_screen "${LSM_SCREENS_DIR}/telegram.sh"
load_screen "${LSM_SCREENS_DIR}/smtp.sh"
load_screen "${LSM_SCREENS_DIR}/ups.sh"
load_screen "${LSM_SCREENS_DIR}/daily_report.sh"
load_screen "${LSM_SCREENS_DIR}/summary.sh"




#
# Стандартная установка
#
# Используются все зарегистрированные модули.
#

wizard_standard_install()
{

    SELECTED_MODULES=()



    while read -r module; do


        [[ -z "${module}" ]] && continue


        SELECTED_MODULES+=("${module}")


    done < <(registry_list)



    #
    # Стандартные параметры
    #

    INSTALL_UPS=true
    UPS_PROFILE="default"



    #
    # Ежедневный отчет
    #
    # Экран настройки будет добавлен позже.
    #

    DAILY_REPORT_ENABLED=true
    DAILY_REPORT_TIME="09:00"

}



#
# Проверка выбранных модулей
#

wizard_validate_modules()
{

    local valid_modules=()

    local module



    for module in "${SELECTED_MODULES[@]}"; do


        if registry_exists "${module}"; then

            valid_modules+=("${module}")


        else

            echo \
                "Предупреждение: модуль '${module}' отсутствует и будет пропущен."

        fi


    done



    SELECTED_MODULES=("${valid_modules[@]}")



    if [[ ${#SELECTED_MODULES[@]} -eq 0 ]]; then


        echo \
            "Предупреждение: модули отсутствуют. Добавлен system."


        SELECTED_MODULES=("system")


    fi

}



#
# Запуск мастера установки
#

run_install_wizard()
{

    wizard_init_tty



    #
    # Приветствие
    #

    screen_welcome



    #
    # Выбор режима
    #

    screen_install_mode



    #
    # Подготовка выбранного режима
    #

    case "${INSTALL_MODE}" in


        standard)


            wizard_standard_install

            ;;


        custom)


            screen_modules

            ;;


        *)


            echo \
                "Неизвестный режим. Используется стандартная установка."

            INSTALL_MODE="standard"

            wizard_standard_install

            ;;


    esac



    #
    # Проверка модулей
    #

    wizard_validate_modules



    #
    # Уведомления
    #

    screen_notifications



    #
    # Telegram
    #

    if [[ "${NOTIFICATION_METHOD:-none}" == "telegram" ]] || \
       [[ "${NOTIFICATION_METHOD:-none}" == "both" ]]; then


        screen_telegram


    fi



    #
    # Email
    #

    if [[ "${NOTIFICATION_METHOD:-none}" == "email" ]] || \
       [[ "${NOTIFICATION_METHOD:-none}" == "both" ]]; then


        screen_smtp


    fi



    #
    # UPS
    #

    screen_ups
    screen_daily_report



    #
    # Итоговая проверка
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



    export DAILY_REPORT_ENABLED
    export DAILY_REPORT_TIME



    #
    # Передача списка модулей
    #

    export SELECTED_MODULES

    export SELECTED_MODULES_STR="${SELECTED_MODULES[*]}"

}
