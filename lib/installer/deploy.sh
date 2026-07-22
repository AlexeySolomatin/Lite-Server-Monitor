#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Installer Deployment Helpers
# -----------------------------------------------------------------------------

set -Eeuo pipefail

# Создание директории с установкой прав и владельца
deploy_create_directory() {
    local target_dir="$1"
    local mode="${2:-755}"
    local owner="${3:-root}"
    local group="${4:-root}"

    log_debug "Creating directory: ${target_dir} (mode: ${mode}, owner: ${owner}:${group})"

    mkdir -p "${target_dir}"
    chmod "${mode}" "${target_dir}"
    chown "${owner}:${group}" "${target_dir}"
}

# Установка/копирование файла с заданными правами и владельцем
deploy_install_file() {
    local source_file="$1"
    local target_file="$2"
    local mode="${3:-644}"
    local owner="${4:-root}"
    local group="${5:-root}"

    if [[ ! -f "${source_file}" ]]; then
        log_error "Source file does not exist: ${source_file}"
        return 1
    fi

    local target_dir
    target_dir="$(dirname "${target_file}")"

    if [[ ! -d "${target_dir}" ]]; then
        deploy_create_directory "${target_dir}" "755" "${owner}" "${group}"
    fi

    log_debug "Installing file: ${source_file} -> ${target_file} (mode: ${mode})"

    cp -f "${source_file}" "${target_file}"
    chmod "${mode}" "${target_file}"
    chown "${owner}:${group}" "${target_file}"
}

# Создание символической ссылки
deploy_create_symlink() {
    local source_path="$1"
    local target_link="$2"

    if [[ ! -e "${source_path}" ]]; then
        log_warn "Target for symlink does not exist yet: ${source_path}"
    fi

    log_debug "Creating symlink: ${target_link} -> ${source_path}"

    local link_dir
    link_dir="$(dirname "${target_link}")"
    if [[ ! -d "${link_dir}" ]]; then
        deploy_create_directory "${link_dir}" "755" "root" "root"
    fi

    ln -sf "${source_path}" "${target_link}"
}

# Безопасное удаление файла или симлинка
deploy_remove_file() {
    local target_file="$1"

    if [[ -f "${target_file}" || -L "${target_file}" ]]; then
        log_debug "Removing file or symlink: ${target_file}"
        rm -f "${target_file}"
    fi
}
