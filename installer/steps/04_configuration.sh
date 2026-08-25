#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Этап 04: Развертывание конфигурации
#
# Путь:
#   installer/steps/04_configuration.sh
#
# Назначение:
#   Создает основные конфигурационные файлы LSM:
#
#   /etc/lsm/config.conf
#       Основные параметры системы.
#
#   /etc/lsm/secrets.conf
#       Секретные данные Telegram и SMTP.
#
#   Конфигурация создается независимо от выбранного режима установки.
# ==============================================================================


set -Eeuo pipefail



readonly CONFIG_COMPONENT="CONFIGURATION"



#
# Основной этап настройки
#

step_configuration()
{

    print_section "Развертывание конфигурации"



    local config_dir="${LSM_ETC_DIR:-/etc/lsm}"

    local config_file="${config_dir}/config.conf"

    local secrets_file="${config_dir}/secrets.conf"



    local template_source="${LSM_ROOT:-/opt/lsm}/templates/config.conf"



    log_info "${CONFIG_COMPONENT}" \
        "Создание конфигурации LSM."



    #
    # Каталог конфигурации
    #

    mkdir -p "${config_dir}"

    chmod 750 "${config_dir}"

    chown root:root "${config_dir}"



    #
    # Основной конфиг.
    #
    # Шаблон копируется только при первом создании файла.
    # Повторная установка и обновление обязаны сохранять
    # пользовательские настройки: конкретные ключи
    # обновляются ниже через config_set().
    #

    if [[ ! -f "${config_file}" ]]; then

        if [[ -f "${template_source}" ]]; then

            cp "${template_source}" "${config_file}"

        else

            touch "${config_file}"

        fi

    fi



    chmod 600 "${config_file}"

    chown root:root "${config_file}"



    #
    # Секретный файл
    #

    if [[ ! -f "${secrets_file}" ]]; then


        cat > "${secrets_file}" <<EOF
# ==============================================================================
# Lite Server Monitor (LSM)
# Секреты уведомлений
#
# Заполняется вручную или мастером установки.
# Имена переменных должны совпадать с lib/notifications/*.
# ==============================================================================


TELEGRAM_BOT_TOKEN=""

TELEGRAM_CHAT_ID=""


SMTP_USER=""

SMTP_PASS=""

SMTP_FROM=""


EOF


    fi



    chmod 600 "${secrets_file}"

    chown root:root "${secrets_file}"



    #
    # Установка параметров
    #

    config_set()
    {

        local key="$1"
        local value="$2"



        if grep -q "^${key}=" "${config_file}" 2>/dev/null; then


            sed -i \
                "s|^${key}=.*|${key}=\"${value}\"|" \
                "${config_file}"


        else


            echo "${key}=\"${value}\"" >> "${config_file}"


        fi

    }



    secret_set()
    {

        local key="$1"
        local value="$2"



        if grep -q "^${key}=" "${secrets_file}" 2>/dev/null; then


            sed -i \
                "s|^${key}=.*|${key}=\"${value}\"|" \
                "${secrets_file}"


        else


            echo "${key}=\"${value}\"" >> "${secrets_file}"


        fi

    }



    #
    # Каналы уведомлений
    #

    case "${NOTIFICATION_METHOD:-none}" in


        telegram)

            config_set TELEGRAM_ENABLED true
            config_set EMAIL_ENABLED false

            ;;


        email)

            config_set TELEGRAM_ENABLED false
            config_set EMAIL_ENABLED true

            ;;


        both)

            config_set TELEGRAM_ENABLED true
            config_set EMAIL_ENABLED true

            ;;


        *)

            config_set TELEGRAM_ENABLED false
            config_set EMAIL_ENABLED false

            ;;

    esac



    #
    # Telegram секреты
    #
    # Мастер установки собирает значения в переменных TG_*,
    # а lib/notifications/telegram.sh читает TELEGRAM_*.
    # Поэтому выполняется отображение имен.
    #

    [[ -n "${TG_BOT_TOKEN:-}" ]] &&
        secret_set TELEGRAM_BOT_TOKEN "${TG_BOT_TOKEN}"


    [[ -n "${TG_CHAT_ID:-}" ]] &&
        secret_set TELEGRAM_CHAT_ID "${TG_CHAT_ID}"



    #
    # Email получатель
    #

    if [[ -n "${ALERT_EMAIL:-}" ]]; then

        config_set ALERT_EMAIL "${ALERT_EMAIL}"

        config_set EMAIL_TO "${ALERT_EMAIL}"

    fi



    #
    # SMTP параметры
    #

    [[ -n "${SMTP_SERVER:-}" ]] &&
        config_set SMTP_SERVER "${SMTP_SERVER}"


    [[ -n "${SMTP_PORT:-}" ]] &&
        config_set SMTP_PORT "${SMTP_PORT}"


    [[ -n "${SMTP_TLS:-}" ]] &&
        config_set SMTP_TLS "${SMTP_TLS}"


    [[ -n "${SMTP_USER:-}" ]] &&
        secret_set SMTP_USER "${SMTP_USER}"


    [[ -n "${SMTP_PASS:-}" ]] &&
        secret_set SMTP_PASS "${SMTP_PASS}"


    [[ -n "${SMTP_FROM:-}" ]] &&
        secret_set SMTP_FROM "${SMTP_FROM}"



    #
    # UPS
    #

    config_set UPS_ENABLED "${INSTALL_UPS:-false}"

    config_set UPS_PROFILE "${UPS_PROFILE:-}"



    #
    # Ежедневный отчет
    #

    config_set DAILY_REPORT_ENABLED \
        "${DAILY_REPORT_ENABLED:-false}"


    config_set DAILY_REPORT_TIME \
        "${DAILY_REPORT_TIME:-09:00}"



    #
    # Защита файлов
    #

    chmod 600 "${config_file}"
    chmod 600 "${secrets_file}"

    chown root:root \
        "${config_file}" \
        "${secrets_file}"



    log_success "${CONFIG_COMPONENT}" \
        "Конфигурация LSM установлена."


}



#
# Автономный запуск
#

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then


    LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

    export LSM_ROOT



    source "${LSM_ROOT}/lib/core/common.sh"
    source "${LSM_ROOT}/lib/core/logging.sh"



    step_configuration


fi
