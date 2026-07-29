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
# Основные системные директории
#

LSM_ETC_DIR="${LSM_ETC_DIR:-/etc/lsm}"
LSM_LOG_DIR="${LSM_LOG_DIR:-/var/log/lsm}"
LSM_DATA_DIR="${LSM_DATA_DIR:-/var/lib/lsm}"



#
# Установка владельца и прав доступа
#

permissions_set()
{
    local path="${1:-}"
    local mode="${2:-}"
    local owner="${3:-root}"
    local group="${4:-root}"


    [[ -n "${path}" ]] || return 1
    [[ -n "${mode}" ]] || return 1
    [[ -e "${path}" ]] || return 1


    chmod "${mode}" "${path}"
    chown "${owner}:${group}" "${path}"
}



#
# Исправление прав директории конфигурации
#

permissions_config()
{
    local target_dir="${LSM_ETC_DIR}"


    if [[ ! -d "${target_dir}" ]]; then
        log_warn "PERMISSIONS" "Каталог конфигурации отсутствует: ${target_dir}"
        return 0
    fi


    log_info "PERMISSIONS" "Настройка прав конфигурации: ${target_dir}"


    permissions_set "${target_dir}" 750 root root || true


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
# Исправление прав директории логов
#

permissions_logs()
{
    local target_dir="${LSM_LOG_DIR}"


    if [[ ! -d "${target_dir}" ]]; then
        log_warn "PERMISSIONS" "Каталог логов отсутствует: ${target_dir}"
        return 0
    fi


    log_info "PERMISSIONS" "Настройка прав логов: ${target_dir}"


    permissions_set "${target_dir}" 750 root root || true


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
# Исправление прав каталога данных
#

permissions_runtime()
{
    local target_dir="${LSM_DATA_DIR}"


    if [[ ! -d "${target_dir}" ]]; then
        log_warn "PERMISSIONS" "Каталог данных отсутствует: ${target_dir}"
        return 0
    fi


    log_info "PERMISSIONS" "Настройка прав данных: ${target_dir}"


    permissions_set "${target_dir}" 750 root root || true


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
# Комплексное исправление всех прав LSM
#

permissions_fix_all()
{
    log_info "PERMISSIONS" "Применение прав доступа LSM..."


    permissions_config
    permissions_logs
    permissions_runtime


    log_success "PERMISSIONS" "Права доступа LSM применены."
}
