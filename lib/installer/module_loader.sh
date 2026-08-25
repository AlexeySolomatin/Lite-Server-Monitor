#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Загрузчик метаданных модулей
#
# Путь:
#   lib/installer/module_loader.sh
#
# Назначение:
#   Загрузка и предоставление метаданных из manifest.conf модулей.
#
# ==============================================================================

set -Eeuo pipefail


[[ -n "${LSM_MODULE_LOADER_LOADED:-}" ]] && return 0
readonly LSM_MODULE_LOADER_LOADED=1



readonly MODULE_LOADER_COMPONENT="MODULE_LOADER"



#
# Пути
#

LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

LSM_MODULES_DIR="${LSM_MODULES_DIR:-${LSM_ROOT}/modules}"

export LSM_MODULES_DIR



#
# Метаданные модуля
#

MODULE_ID=""
MODULE_NAME=""
MODULE_DESCRIPTION=""
MODULE_VERSION=""
MODULE_CATEGORY=""
MODULE_DEPENDENCIES=""
MODULE_DEFAULT=""



#
# Инициализация
#

module_loader_init()
{

    if [[ ! -d "${LSM_MODULES_DIR}" ]]; then

        log_error \
            "${MODULE_LOADER_COMPONENT}" \
            "Каталог модулей отсутствует: ${LSM_MODULES_DIR}"

        return 1

    fi


    return 0

}



#
# Очистка метаданных
#

module_clear_metadata()
{

    MODULE_ID=""
    MODULE_NAME=""
    MODULE_DESCRIPTION=""
    MODULE_VERSION=""
    MODULE_CATEGORY=""
    MODULE_DEPENDENCIES=""
    MODULE_DEFAULT=""

}



#
# Загрузка manifest.conf
#

module_load_manifest()
{

    local module="${1:-}"


    [[ -n "${module}" ]] || return 1



    local manifest="${LSM_MODULES_DIR}/${module}/manifest.conf"



    if [[ ! -f "${manifest}" ]]; then

        log_error \
            "${MODULE_LOADER_COMPONENT}" \
            "Manifest отсутствует: ${module}"

        return 1

    fi



    module_clear_metadata



    if ! source "${manifest}"; then

        log_error \
            "${MODULE_LOADER_COMPONENT}" \
            "Ошибка чтения manifest: ${module}"

        return 1

    fi



    if [[ -z "${MODULE_ID}" ]]; then

        MODULE_ID="${module}"

    fi



    return 0

}



#
# Список модулей
#

module_loader_list()
{

    [[ -d "${LSM_MODULES_DIR}" ]] || return 0


    find "${LSM_MODULES_DIR}" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -printf "%f\n" \
        2>/dev/null \
        | sort

}



#
# Получение метаданных
#

module_get_name()
{
    local module="${1:-}"

    if module_load_manifest "${module}"; then
        echo "${MODULE_NAME:-${module}}"
    else
        echo "${module}"
    fi
}



module_get_version()
{
    local module="${1:-}"

    if module_load_manifest "${module}"; then
        echo "${MODULE_VERSION:-unknown}"
    else
        echo "unknown"
    fi
}



module_get_dependencies()
{
    local module="${1:-}"

    if module_load_manifest "${module}"; then
        echo "${MODULE_DEPENDENCIES:-}"
    fi
}



module_has_manifest()
{
    local module="${1:-}"

    [[ -f "${LSM_MODULES_DIR}/${module}/manifest.conf" ]]
}



#
# Вывод информации о модуле
#

module_info()
{

    local module="${1:-}"


    module_load_manifest "${module}" || return 1



cat <<EOF

ID:
${MODULE_ID}

Название:
${MODULE_NAME}

Описание:
${MODULE_DESCRIPTION}

Версия:
${MODULE_VERSION}

Категория:
${MODULE_CATEGORY}

Зависимости:
${MODULE_DEPENDENCIES:-нет}

По умолчанию:
${MODULE_DEFAULT:-no}

EOF

}
