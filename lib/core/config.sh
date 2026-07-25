#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Управление конфигурационными файлами
# Путь: lib/core/config.sh
# ==============================================================================

set -Eeuo pipefail


[[ -n "${LSM_CONFIG_LOADED:-}" ]] && return 0
readonly LSM_CONFIG_LOADED=1



#
# Paths
#

: "${LSM_CONFIG_DIR:=/etc/lsm}"

: "${CONFIG_DIR:=${LSM_CONFIG_DIR}}"

: "${CONFIG_FILE:=${CONFIG_DIR}/config.conf}"

: "${TEMPLATES_DIR:=${LSM_ROOT:-/opt/lsm}/templates}"



#
# Check config
#

config_exists()
{

    local target="${1:-${CONFIG_FILE}}"

    [[ -f "${target}" ]]

}



#
# Safe source
#

_config_source()
{

    local file="$1"


    if ! source "${file}"; then

        if declare -f log_error >/dev/null 2>&1; then

            log_error \
                "CONFIG" \
                "Ошибка загрузки файла: ${file}"

        fi

        return 1

    fi

}



#
# Load single config
#

load_config()
{

    local target="${1:-${CONFIG_FILE}}"


    if [[ ! -f "${target}" ]]; then


        if declare -f log_error >/dev/null 2>&1; then

            log_error \
                "CONFIG" \
                "Файл не найден: ${target}"

        fi


        return 1

    fi


    _config_source "${target}"

}



#
# Load all configs
#

load_all_configs()
{

    local configs=(

        "config.conf"
        "modules.conf"
        "notifications.conf"
        "thresholds.conf"
        "secrets.conf"

    )


    for cfg in "${configs[@]}"
    do

        local path="${CONFIG_DIR}/${cfg}"


        [[ -f "${path}" ]] || continue



        if [[ "${cfg}" == "secrets.conf" ]]; then

            chmod 600 "${path}" 2>/dev/null || true

        fi


        _config_source "${path}" || return 1


    done


}



#
# Validation
#

validate_config()
{

    local errors=0



    if [[ -z "${LSM_HOSTNAME:-}" ]]; then

        export LSM_HOSTNAME="$(
            hostname -s 2>/dev/null || echo unknown-host
        )"


        if declare -f log_warn >/dev/null 2>&1; then

            log_warn \
                "CONFIG" \
                "LSM_HOSTNAME не задан. Используется ${LSM_HOSTNAME}"

        fi

    fi



    return "${errors}"

}



#
# Create config directory
#

create_config_dir()
{

    mkdir -p "${CONFIG_DIR}"

    chmod 750 "${CONFIG_DIR}"

}



#
# Install default config
#

install_default_config()
{


    if config_exists; then


        if declare -f log_info >/dev/null 2>&1; then

            log_info \
                "CONFIG" \
                "Конфигурация уже существует."

        fi


        return 0

    fi



    create_config_dir



    local template="${TEMPLATES_DIR}/config.conf"



    if [[ ! -f "${template}" ]]; then


        if declare -f log_error >/dev/null 2>&1; then

            log_error \
                "CONFIG" \
                "Шаблон не найден: ${template}"

        fi


        return 1

    fi



    cp "${template}" "${CONFIG_FILE}"


    chmod 640 "${CONFIG_FILE}"



    if declare -f log_success >/dev/null 2>&1; then

        log_success \
            "CONFIG" \
            "Базовая конфигурация установлена."

    fi


}
