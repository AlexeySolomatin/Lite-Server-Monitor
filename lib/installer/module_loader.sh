#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Module Metadata Loader
# Path: lib/installer/module_loader.sh
# ==============================================================================

set -Eeuo pipefail


[[ -n "${LSM_MODULE_LOADER_LOADED:-}" ]] && return 0
readonly LSM_MODULE_LOADER_LOADED=1


LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

LSM_MODULES_DIR="${LSM_MODULES_DIR:-${LSM_ROOT}/modules}"

export LSM_MODULES_DIR



#
# Current metadata cache
#

MODULE_ID=""
MODULE_NAME=""
MODULE_DESCRIPTION=""
MODULE_VERSION=""
MODULE_CATEGORY=""
MODULE_DEPENDENCIES=""
MODULE_DEFAULT=""



module_loader_init()
{
    [[ -d "${LSM_MODULES_DIR}" ]] || {
        log_warn "Каталог модулей отсутствует: ${LSM_MODULES_DIR}"
        return 1
    }

    return 0
}



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



module_load_manifest()
{

    local module="${1:-}"

    [[ -n "${module}" ]] || return 1


    local manifest="${LSM_MODULES_DIR}/${module}/manifest.conf"


    if [[ ! -f "${manifest}" ]]; then

        log_warn "Manifest отсутствует: ${module}"

        return 1

    fi


    module_clear_metadata


    # shellcheck disable=SC1090
    set +u
    source "${manifest}"
    set -u


    return 0

}



#
# Универсальный getter
#

module_get_field()
{

    local module="$1"
    local field="$2"


    if ! module_load_manifest "${module}"; then
        return 1
    fi


    case "${field}" in

        MODULE_ID)
            echo "${MODULE_ID}"
        ;;

        MODULE_NAME)
            echo "${MODULE_NAME}"
        ;;

        MODULE_DESCRIPTION)
            echo "${MODULE_DESCRIPTION}"
        ;;

        MODULE_VERSION)
            echo "${MODULE_VERSION}"
        ;;

        MODULE_CATEGORY)
            echo "${MODULE_CATEGORY}"
        ;;

        MODULE_DEPENDENCIES)
            echo "${MODULE_DEPENDENCIES}"
        ;;

        MODULE_DEFAULT)
            echo "${MODULE_DEFAULT}"
        ;;

        *)
            return 1
        ;;

    esac

}



module_loader_list()
{

    [[ -d "${LSM_MODULES_DIR}" ]] || return 0


    find "${LSM_MODULES_DIR}" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -printf "%f\n" \
        2>/dev/null | sort

}



module_get_name()
{
    module_get_field "$1" MODULE_NAME
}



module_get_description()
{
    module_get_field "$1" MODULE_DESCRIPTION
}



module_get_category()
{
    module_get_field "$1" MODULE_CATEGORY
}



module_get_version()
{
    module_get_field "$1" MODULE_VERSION
}



module_has_manifest()
{
    [[ -f "${LSM_MODULES_DIR}/${1}/manifest.conf" ]]
}



module_validate()
{

    local module="$1"


    if ! module_has_manifest "${module}"; then

        log_error "Нет manifest.conf: ${module}"

        return 1

    fi


    if [[ ! -f "${LSM_MODULES_DIR}/${module}/install.sh" ]]; then

        log_error "Нет install.sh: ${module}"

        return 1

    fi


    return 0

}



module_info()
{

    local module="$1"


    module_load_manifest "${module}" || return 1


cat <<EOF
ID: ${MODULE_ID}

Название: ${MODULE_NAME}

Описание: ${MODULE_DESCRIPTION}

Версия: ${MODULE_VERSION}

Категория: ${MODULE_CATEGORY}

Зависимости: ${MODULE_DEPENDENCIES:-нет}

По умолчанию: ${MODULE_DEFAULT:-нет}
EOF

}
