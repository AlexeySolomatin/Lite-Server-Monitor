#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Вспомогательная библиотека установки и развертывания компонентов
# Путь: lib/installer/deploy.sh
# ==============================================================================

set -Eeuo pipefail

# Защита от повторного подключения файла
[[ -n "${LSM_DEPLOY_LOADED:-}" ]] && return 0
readonly LSM_DEPLOY_LOADED=1

#
# Создание директории с установкой прав доступа и владельца
#
deploy_create_directory() {
    local target_dir="${1:-}"
    local mode="${2:-755}"
    local owner="${3:-root}"
    local group="${4:-root}"

    if [[ -z "${target_dir}" ]]; then
        return 1
    fi

    if declare -f log_debug >/dev/null 2>&1; then
        log_debug "DEPLOY" "Создание директории: ${target_dir} (права: ${mode}, владелец: ${owner}:${group})"
    fi

    mkdir -p "${target_dir}"
    chmod "${mode}" "${target_dir}"
    chown "${owner}:${group}" "${target_dir}"
}

#
# Установка/копирование файла с заданными правами и владельцем
#
deploy_install_file() {
    local source_file="${1:-}"
    local target_file="${2:-}"
    local mode="${3:-644}"
    local owner="${4:-root}"
    local group="${5:-root}"

    if [[ -z "${source_file}" || -z "${target_file}" ]]; then
        return 1
    fi

    if [[ ! -f "${source_file}" ]]; then
        if declare -f log_error >/dev/null 2>&1; then
            log_error "DEPLOY" "Исходный файл не существует: ${source_file}"
        else
            echo "Ошибка: Исходный файл не существует: ${source_file}" >&2
        fi
        return 1
    fi

    local target_dir
    target_dir="$(dirname "${target_file}")"

    if [[ ! -d "${target_dir}" ]]; then
        deploy_create_directory "${target_dir}" "755" "${owner}" "${group}"
    fi

    if declare -f log_debug >/dev/null 2>&1; then
        log_debug "DEPLOY" "Установка файла: ${source_file} -> ${target_file} (права: ${mode})"
    fi

    cp -f "${source_file}" "${target_file}"
    chmod "${mode}" "${target_file}"
    chown "${owner}:${group}" "${target_file}"
}

#
# Создание символической ссылки
#
deploy_create_symlink() {
    local source_path="${1:-}"
    local target_link="${2:-}"

    if [[ -z "${source_path}" || -z "${target_link}" ]]; then
        return 1
    fi

    if [[ ! -e "${source_path}" ]]; then
        if declare -f log_warn >/dev/null 2>&1; then
            log_warn "DEPLOY" "Цель для символической ссылки пока не существует: ${source_path}"
        fi
    fi

    if declare -f log_debug >/dev/null 2>&1; then
        log_debug "DEPLOY" "Создание символической ссылки: ${target_link} -> ${source_path}"
    fi

    local link_dir
    link_dir="$(dirname "${target_link}")"
    if [[ ! -d "${link_dir}" ]]; then
        deploy_create_directory "${link_dir}" "755" "root" "root"
    fi

    ln -sf "${source_path}" "${target_link}"
}

#
# Безопасное удаление файла или символической ссылки
#
deploy_remove_file() {
    local target_file="${1:-}"

    if [[ -n "${target_file}" && ( -f "${target_file}" || -L "${target_file}" ) ]]; then
        if declare -f log_debug >/dev/null 2>&1; then
            log_debug "DEPLOY" "Удаление файла или символической ссылки: ${target_file}"
        fi
        rm -f "${target_file}"
    fi
}
