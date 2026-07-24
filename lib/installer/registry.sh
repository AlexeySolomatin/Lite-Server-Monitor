#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Реестр модулей установки
# Путь: lib/installer/registry.sh
# ==============================================================================

set -Eeuo pipefail


[[ -n "${LSM_INSTALL_REGISTRY_LOADED:-}" ]] && return 0
readonly LSM_INSTALL_REGISTRY_LOADED=1



#
# Paths
#

LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

LSM_MODULES_DIR="${LSM_MODULES_DIR:-${LSM_ROOT}/modules}"



#
# Registry storage
#

declare -A LSM_MODULE_NAME
declare -A LSM_MODULE_DESCRIPTION
declare -A LSM_MODULE_VERSION
declare -A LSM_MODULE_CATEGORY
declare -A LSM_MODULE_DEPENDENCIES


declare -a LSM_MODULES=()



#
# Add module
#

registry_add()
{
    local module="$1"


    [[ -n "${module}" ]] || return 1



    if ! declare -f module_has_manifest >/dev/null 2>&1; then

        log_error "API module_loader недоступен."

        return 1

    fi



    if ! module_has_manifest "${module}"; then

        log_warn \
            "Модуль ${module}: manifest.conf отсутствует"

        return 1

    fi



    if ! module_load_manifest "${module}"; then

        log_warn \
            "Модуль ${module}: ошибка загрузки manifest.conf"

        return 1

    fi



    LSM_MODULES+=("${module}")


    LSM_MODULE_NAME["${module}"]="${MODULE_NAME:-${module}}"

    LSM_MODULE_DESCRIPTION["${module}"]="${MODULE_DESCRIPTION:-}"

    LSM_MODULE_VERSION["${module}"]="${MODULE_VERSION:-unknown}"

    LSM_MODULE_CATEGORY["${module}"]="${MODULE_CATEGORY:-unknown}"

    LSM_MODULE_DEPENDENCIES["${module}"]="${MODULE_DEPENDENCIES:-}"

}



#
# Scan modules directory
#

registry_scan()
{

    LSM_MODULES=()



    [[ -d "${LSM_MODULES_DIR}" ]] || return 0



    while read -r module
    do

        [[ -z "${module}" ]] && continue


        registry_add "${module}" || true


    done < <(

        find "${LSM_MODULES_DIR}" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            -printf "%f\n" \
            2>/dev/null \
            | sort

    )

}



#
# Load registry
#

registry_load_default()
{

    registry_scan

}



#
# Check module exists
#

registry_exists()
{

    local module="$1"


    [[ -n "${LSM_MODULE_NAME[$module]:-}" ]]

}



#
# List modules
#

registry_list()
{

    printf "%s\n" "${LSM_MODULES[@]}"

}



#
# Module information
#

registry_info()
{

    local module="$1"



    if ! registry_exists "${module}"; then

        return 1

    fi



cat <<EOF

Модуль:
${module}

Название:
${LSM_MODULE_NAME[$module]}

Описание:
${LSM_MODULE_DESCRIPTION[$module]}

Версия:
${LSM_MODULE_VERSION[$module]}

Категория:
${LSM_MODULE_CATEGORY[$module]}

Зависимости:
${LSM_MODULE_DEPENDENCIES[$module]:-нет}

EOF

}



#
# Dependencies
#

registry_dependencies()
{

    local module="$1"


    echo "${LSM_MODULE_DEPENDENCIES[$module]:-}"

}



#
# Dependency validation
#

registry_check_dependencies()
{

    local module="$1"



    if ! registry_exists "${module}"; then

        log_error \
            "Модуль ${module} отсутствует в registry."

        return 1

    fi



    local deps

    deps=$(registry_dependencies "${module}")



    [[ -z "${deps}" ]] && return 0



    for dep in ${deps}
    do

        if ! registry_exists "${dep}"; then

            log_error \
                "Модуль ${module}: отсутствует зависимость ${dep}"

            return 1

        fi

    done



    return 0

}



#
# Resolve installation order
#

registry_resolve_order()
{

    local requested=("$@")


    local result=()



    for module in "${requested[@]}"
    do

        registry_resolve_module \
            "${module}" \
            result

    done



    printf "%s\n" "${result[@]}"

}



#
# Recursive dependency resolver
#

registry_resolve_module()
{

    local module="$1"

    local -n output="$2"



    for item in "${output[@]}"
    do

        [[ "${item}" == "${module}" ]] && return

    done



    local deps

    deps=$(registry_dependencies "${module}")



    for dep in ${deps}
    do

        registry_resolve_module \
            "${dep}" \
            output

    done



    output+=("${module}")

}
