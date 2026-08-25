#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Вспомогательная библиотека работы с файловой системой
#
# Путь:
#   lib/core/filesystem.sh
#
# ==============================================================================

set -Eeuo pipefail

# Защита от повторного подключения файла
[[ -n "${LSM_FILESYSTEM_LOADED:-}" ]] && return 0
readonly LSM_FILESYSTEM_LOADED=1

#
# Проверка существования обычного файла
#
file_exists() {
    local file="${1:-}"
    [[ -n "${file}" && -f "${file}" ]]
}

#
# Проверка существования директории
#
dir_exists() {
    local dir="${1:-}"
    [[ -n "${dir}" && -d "${dir}" ]]
}

#
# Гарантированное создание директории
#
ensure_directory() {
    local dir="${1:-}"
    if [[ -n "${dir}" && ! -d "${dir}" ]]; then
        mkdir -p "${dir}"
    fi
}

#
# Гарантированное создание родительской директории для указанного пути
#
ensure_parent_directory() {
    local target="${1:-}"
    if [[ -n "${target}" ]]; then
        local parent_dir
        parent_dir="$(dirname "${target}")"
        ensure_directory "${parent_dir}"
    fi
}

#
# Безопасное копирование файла или директории (с автоматическим созданием целевого пути)
#
safe_copy() {
    local source="${1:-}"
    local destination="${2:-}"

    if [[ -z "${source}" || -z "${destination}" ]]; then
        if declare -f log_error >/dev/null 2>&1; then
            log_error "FILESYSTEM" "safe_copy: Не указан источник или целевой путь."
        else
            echo "Ошибка: safe_copy: Не указан источник или целевой путь." >&2
        fi
        return 1
    fi

    if [[ ! -e "${source}" ]]; then
        if declare -f log_error >/dev/null 2>&1; then
            log_error "FILESYSTEM" "safe_copy: Исходный объект не существует: ${source}"
        else
            echo "Ошибка: safe_copy: Исходный объект не существует: ${source}" >&2
        fi
        return 1
    fi

    ensure_parent_directory "${destination}"
    cp -r "${source}" "${destination}"
}

#
# Безопасное перемещение файла или директории
#
safe_move() {
    local source="${1:-}"
    local destination="${2:-}"

    if [[ -z "${source}" || -z "${destination}" ]]; then
        if declare -f log_error >/dev/null 2>&1; then
            log_error "FILESYSTEM" "safe_move: Не указан источник или целевой путь."
        else
            echo "Ошибка: safe_move: Не указан источник или целевой путь." >&2
        fi
        return 1
    fi

    if [[ ! -e "${source}" ]]; then
        if declare -f log_error >/dev/null 2>&1; then
            log_error "FILESYSTEM" "safe_move: Исходный объект не существует: ${source}"
        else
            echo "Ошибка: safe_move: Исходный объект не существует: ${source}" >&2
        fi
        return 1
    fi

    ensure_parent_directory "${destination}"
    mv "${source}" "${destination}"
}

#
# Безопасное удаление файла или директории
#
safe_remove() {
    local target="${1:-}"

    if [[ -n "${target}" && -e "${target}" ]]; then
        rm -rf "${target}"
    fi
}

#
# Установка владельца и группы для объекта
# Использование: set_owner "user" "group" "/path/to/target" ИЛИ set_owner "user" "" "/path/to/target"
#
set_owner() {
    local owner="${1:-}"
    local group="${2:-}"
    local target="${3:-}"

    if [[ -z "${owner}" || -z "${target}" ]]; then
        return 1
    fi

    if [[ -e "${target}" ]]; then
        if [[ -n "${group}" ]]; then
            chown "${owner}:${group}" "${target}"
        else
            chown "${owner}" "${target}"
        fi
    fi
}

#
# Установка прав доступа для объекта
# Использование: set_permissions "640" "/path/to/target"
#
set_permissions() {
    local mode="${1:-}"
    local target="${2:-}"

    if [[ -n "${mode}" && -n "${target}" && -e "${target}" ]]; then
        chmod "${mode}" "${target}"
    fi
}
