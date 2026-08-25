#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Вспомогательная библиотека установки и развертывания компонентов
#
# Путь:
#   lib/installer/deploy.sh
#
# ==============================================================================

set -Eeuo pipefail


[[ -n "${LSM_DEPLOY_LOADED:-}" ]] && return 0
readonly LSM_DEPLOY_LOADED=1


#
# Гарантированное определение корня и подгрузка логирования
#

if [[ -z "${LSM_ROOT:-}" ]]; then
    LSM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

if [[ -f "${LSM_ROOT}/lib/core/logging.sh" ]]; then
    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/core/logging.sh"
fi

# Аварийный фоллбэк, если logging.sh не загрузился
if ! declare -f log_info >/dev/null 2>&1; then
    log_info()  { printf "[INFO   ] [%s] %s\n" "${1:-}" "${2:-}"; }
    log_debug() { printf "[DEBUG  ] [%s] %s\n" "${1:-}" "${2:-}"; }
    log_warn()  { printf "[WARN   ] [%s] %s\n" "${1:-}" "${2:-}"; }
    log_error() { printf "[ERROR  ] [%s] %s\n" "${1:-}" "${2:-}" >&2; }
fi


readonly DEPLOY_COMPONENT="DEPLOY"



#
# Создание директории
#

deploy_create_directory()
{
    local target_dir="${1:-}"
    local mode="${2:-755}"
    local owner="${3:-root}"
    local group="${4:-root}"


    [[ -n "${target_dir}" ]] || return 1



    log_debug \
        "${DEPLOY_COMPONENT}" \
        "Создание каталога: ${target_dir}"



    mkdir -p "${target_dir}"

    chmod "${mode}" "${target_dir}"

    chown "${owner}:${group}" "${target_dir}"



    log_debug \
        "${DEPLOY_COMPONENT}" \
        "Каталог готов: ${target_dir}"

}



#
# Установка файла
#

deploy_install_file()
{
    local source_file="${1:-}"
    local target_file="${2:-}"
    local mode="${3:-644}"
    local owner="${4:-root}"
    local group="${5:-root}"



    [[ -n "${source_file}" ]] || return 1
    [[ -n "${target_file}" ]] || return 1



    if [[ ! -f "${source_file}" ]]; then

        log_error \
            "${DEPLOY_COMPONENT}" \
            "Источник отсутствует: ${source_file}"

        return 1

    fi



    local target_dir

    target_dir="$(dirname "${target_file}")"



    if [[ ! -d "${target_dir}" ]]; then

        deploy_create_directory \
            "${target_dir}" \
            "755" \
            "${owner}" \
            "${group}"

    fi



    log_info \
        "${DEPLOY_COMPONENT}" \
        "Установка файла: ${target_file}"



    cp -f \
        "${source_file}" \
        "${target_file}"



    chmod "${mode}" "${target_file}"

    chown "${owner}:${group}" "${target_file}"



    if [[ ! -f "${target_file}" ]]; then

        log_error \
            "${DEPLOY_COMPONENT}" \
            "Файл не установлен: ${target_file}"

        return 1

    fi


}



#
# Создание symlink
#

deploy_create_symlink()
{
    local source_path="${1:-}"
    local target_link="${2:-}"



    [[ -n "${source_path}" ]] || return 1
    [[ -n "${target_link}" ]] || return 1



    if [[ ! -e "${source_path}" ]]; then

        log_warn \
            "${DEPLOY_COMPONENT}" \
            "Источник ссылки отсутствует: ${source_path}"

    fi



    local link_dir

    link_dir="$(dirname "${target_link}")"



    if [[ ! -d "${link_dir}" ]]; then

        deploy_create_directory \
            "${link_dir}" \
            "755" \
            "root" \
            "root"

    fi



    log_info \
        "${DEPLOY_COMPONENT}" \
        "Создание ссылки: ${target_link}"



    ln -sfn \
        "${source_path}" \
        "${target_link}"

}



#
# Удаление файла или ссылки
#

deploy_remove_file()
{
    local target_file="${1:-}"



    [[ -n "${target_file}" ]] || return 0



    if [[ -f "${target_file}" || -L "${target_file}" ]]; then


        log_info \
            "${DEPLOY_COMPONENT}" \
            "Удаление: ${target_file}"


        rm -f "${target_file}"

    fi
}

#
# Удаление директории
#

deploy_remove_directory()
{
    local target_dir="${1:-}"

    [[ -n "${target_dir}" ]] || return 0

    if [[ -d "${target_dir}" ]]; then

        log_info \
            "${DEPLOY_COMPONENT}" \
            "Удаление каталога: ${target_dir}"

        rm -rf "${target_dir}"

    fi
}
