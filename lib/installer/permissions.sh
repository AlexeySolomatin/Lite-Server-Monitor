#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Библиотека управления правами доступа и владельцами файлов
# Путь: lib/installer/permissions.sh
# ==============================================================================

set -Eeuo pipefail


[[ -n "${LSM_PERMISSIONS_LOADED:-}" ]] && return 0
readonly LSM_PERMISSIONS_LOADED=1



#
# Компонент
#

readonly PERMISSIONS_COMPONENT="PERMISSIONS"



#
# Основные директории
#

LSM_ETC_DIR="${LSM_ETC_DIR:-/etc/lsm}"
LSM_LOG_DIR="${LSM_LOG_DIR:-/var/log/lsm}"
LSM_DATA_DIR="${LSM_DATA_DIR:-/var/lib/lsm}"



#
# Проверка root
#

permissions_check_root()
{
    if [[ "${EUID}" -ne 0 ]]; then

        log_error "${PERMISSIONS_COMPONENT}" \
            "Для изменения прав нужны права root."

        return 1

    fi
}



#
# Создание каталога
#

permissions_ensure_directory()
{
    local path="${1:-}"
    local mode="${2:-750}"


    [[ -n "${path}" ]] || return 1


    if [[ ! -d "${path}" ]]; then

        mkdir -p "${path}"

        log_info "${PERMISSIONS_COMPONENT}" \
            "Создан каталог: ${path}"

    fi


    chmod "${mode}" "${path}"
    chown root:root "${path}"
}



#
# Установка прав отдельного объекта
#

permissions_set()
{
    local path="${1:-}"
    local mode="${2:-}"
    local owner="${3:-root}"
    local group="${4:-root}"


    [[ -n "${path}" ]] || return 1
    [[ -e "${path}" ]] || return 1


    chmod "${mode}" "${path}"
    chown "${owner}:${group}" "${path}"
}



#
# Исправление прав конфигурации
#

permissions_config()
{
    local target_dir="${LSM_ETC_DIR}"


    permissions_ensure_directory "${target_dir}" 750


    log_info "${PERMISSIONS_COMPONENT}" \
        "Настройка конфигурации: ${target_dir}"



    find "${target_dir}" \
        -type d \
        -exec chmod 750 {} \; \
        2>/dev/null || true



    find "${target_dir}" \
        -type f \
        -exec chmod 640 {} \; \
        2>/dev/null || true



    #
    # Файл секретов должен быть закрыт
    #

    if [[ -f "${target_dir}/secrets.conf" ]]; then

        chmod 600 "${target_dir}/secrets.conf"
        chown root:root "${target_dir}/secrets.conf"

        log_info "${PERMISSIONS_COMPONENT}" \
            "Защищен файл секретов: secrets.conf"

    fi
}



#
# Исправление прав логов
#

permissions_logs()
{
    local target_dir="${LSM_LOG_DIR}"


    permissions_ensure_directory "${target_dir}" 750


    log_info "${PERMISSIONS_COMPONENT}" \
        "Настройка логов: ${target_dir}"



    find "${target_dir}" \
        -type d \
        -exec chmod 750 {} \; \
        2>/dev/null || true



    find "${target_dir}" \
        -type f \
        -exec chmod 640 {} \; \
        2>/dev/null || true
}



#
# Исправление прав данных
#

permissions_runtime()
{
    local target_dir="${LSM_DATA_DIR}"


    permissions_ensure_directory "${target_dir}" 750


    log_info "${PERMISSIONS_COMPONENT}" \
        "Настройка данных: ${target_dir}"



    find "${target_dir}" \
        -type d \
        -exec chmod 750 {} \; \
        2>/dev/null || true



    find "${target_dir}" \
        -type f \
        -exec chmod 640 {} \; \
        2>/dev/null || true
}



#
# Полное применение прав LSM
#

permissions_fix_all()
{
    permissions_check_root || return 1


    log_info "${PERMISSIONS_COMPONENT}" \
        "Применение прав доступа LSM..."



    permissions_config
    permissions_logs
    permissions_runtime



    log_success "${PERMISSIONS_COMPONENT}" \
        "Права доступа LSM применены."
}
