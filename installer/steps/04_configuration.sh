#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Step 04: Configuration Deployment
# -----------------------------------------------------------------------------

set -Eeuo pipefail


readonly CONFIG_COMPONENT="CONFIGURATION"



step_configuration()
{

    print_section "Configuration Deployment"



    local config_dir="${LSM_ETC_DIR:-/etc/lsm}"

    local config_file="${config_dir}/config.conf"

    local template_source="${LSM_ROOT:-/opt/lsm}/templates/config.conf"



    log_info "${CONFIG_COMPONENT}" \
        "Развертывание конфигурации LSM."



    #
    # Создание каталога конфигурации
    #

    if declare -f deploy_create_directory >/dev/null 2>&1; then


        deploy_create_directory \
            "${config_dir}" \
            "750" \
            "root" \
            "root"


    else


        mkdir -p "${config_dir}"

        chmod 750 "${config_dir}"

        chown root:root "${config_dir}"


    fi



    #
    # Проверка шаблона
    #

    if [[ ! -f "${template_source}" ]]; then


        log_error "${CONFIG_COMPONENT}" \
            "Шаблон конфигурации отсутствует: ${template_source}"


        return 1

    fi



    #
    # Резервная копия существующего конфига
    #

    if [[ -f "${config_file}" ]]; then


        local backup_file

        backup_file="${config_file}.bak.$(date +%Y%m%d_%H%M%S)"



        log_warn "${CONFIG_COMPONENT}" \
            "Обнаружен существующий конфиг. Создание резервной копии: ${backup_file}"



        cp -a \
            "${config_file}" \
            "${backup_file}"


        chmod 600 "${backup_file}"
        chown root:root "${backup_file}"


    fi



    #
    # Установка базового конфига
    #

    if declare -f deploy_install_file >/dev/null 2>&1; then


        deploy_install_file \
            "${template_source}" \
            "${config_file}" \
            "600" \
            "root" \
            "root"


    else


        cp "${template_source}" "${config_file}"

        chmod 600 "${config_file}"

        chown root:root "${config_file}"


    fi



    #
    # Замена параметров
    #

    config_set()
    {
        local key="$1"
        local value="$2"


        sed -i \
            "s|^${key}=.*|${key}=\"${value}\"|" \
            "${config_file}"
    }



    log_info "${CONFIG_COMPONENT}" \
        "Применение параметров установки."



    #
    # Notification mode
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
    # Telegram
    #

    [[ -n "${TG_BOT_TOKEN:-}" ]] &&
        config_set TELEGRAM_BOT_TOKEN "${TG_BOT_TOKEN}"


    [[ -n "${TG_CHAT_ID:-}" ]] &&
        config_set TELEGRAM_CHAT_ID "${TG_CHAT_ID}"



    #
    # SMTP
    #

    [[ -n "${SMTP_SERVER:-}" ]] &&
        config_set SMTP_SERVER "${SMTP_SERVER}"


    [[ -n "${SMTP_PORT:-}" ]] &&
        config_set SMTP_PORT "${SMTP_PORT}"


    [[ -n "${SMTP_TLS:-}" ]] &&
        config_set SMTP_TLS "${SMTP_TLS}"


    [[ -n "${SMTP_USERNAME:-}" ]] &&
        config_set SMTP_USER "${SMTP_USERNAME}"


    [[ -n "${SMTP_PASSWORD:-}" ]] &&
        config_set SMTP_PASS "${SMTP_PASSWORD}"


    [[ -n "${SMTP_FROM:-}" ]] &&
        config_set SMTP_FROM "${SMTP_FROM}"



    #
    # Финальная защита
    #

    chmod 600 "${config_file}"

    chown root:root "${config_file}"



    log_success "${CONFIG_COMPONENT}" \
        "Конфигурация LSM успешно установлена."


    return 0

}



#
# Автономный запуск
#

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then


    LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

    export LSM_ROOT



    source "${LSM_ROOT}/lib/core/common.sh"
    source "${LSM_ROOT}/lib/core/logging.sh"
    source "${LSM_ROOT}/lib/installer/deploy.sh"



    step_configuration


fi
