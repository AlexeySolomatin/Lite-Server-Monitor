#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Module Registry API v1.2
# Путь: lib/installer/registry.sh
# ==============================================================================

set -Eeuo pipefail


[[ -n "${LSM_INSTALL_REGISTRY_LOADED:-}" ]] && return 0
readonly LSM_INSTALL_REGISTRY_LOADED=1



readonly REGISTRY_COMPONENT="REGISTRY"



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


declare -A LSM_MODULE_EXISTS

declare -A LSM_RESOLVING


declare -a LSM_MODULES=()



#
# Clear registry
#

registry_clear()
{
    LSM_MODULE_NAME=()
    LSM_MODULE_DESCRIPTION=()
    LSM_MODULE_VERSION=()
    LSM_MODULE_CATEGORY=()
    LSM_MODULE_DEPENDENCIES=()
    LSM_MODULE_EXISTS=()

    LSM_MODULES=()
}



#
# Add module
#

registry_add()
{
    local module="${1:-}"


    [[ -n "${module}" ]] || return 1


    if [[ -v LSM_MODULE_EXISTS[$module] ]]; then
        return 0
    fi



    if ! module_has_manifest "${module}"; then

        log_warn \
            "${REGISTRY_COMPONENT}" \
            "Manifest отсутствует: ${module}"

        return 1

    fi



    if ! module_load_manifest "${module}"; then

        log_error \
            "${REGISTRY_COMPONENT}" \
            "Ошибка загрузки manifest: ${module}"

        return 1

    fi



    LSM_MODULE_EXISTS["${module}"]=1


    LSM_MODULES+=("${module}")


    LSM_MODULE_NAME["${module}"]="${MODULE_NAME:-${module}}"

    LSM_MODULE_DESCRIPTION["${module}"]="${MODULE_DESCRIPTION:-}"

    LSM_MODULE_VERSION["${module}"]="${MODULE_VERSION:-unknown}"

    LSM_MODULE_CATEGORY["${module}"]="${MODULE_CATEGORY:-unknown}"

    LSM_MODULE_DEPENDENCIES["${module}"]="${MODULE_DEPENDENCIES:-}"

}



#
# Scan
#

registry_scan()
{
    registry_clear


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
            | sort

    )
}



#
# Load
#

registry_load_default()
{
    registry_scan
}



#
# Exists
#

registry_exists()
{
    local module="${1:-}"

    [[ -v LSM_MODULE_EXISTS[$module] ]]
}



#
# List
#

registry_list()
{
    printf "%s\n" "${LSM_MODULES[@]}"
}



#
# Dependencies
#

registry_dependencies()
{
    local module="${1:-}"

    echo "${LSM_MODULE_DEPENDENCIES[$module]:-}"
}



#
# Resolve
#

registry_resolve_order()
{
    local requested=("$@")

    local result=()


    LSM_RESOLVING=()



    for module in "${requested[@]}"
    do

        registry_resolve_module \
            "${module}" \
            result || return 1

    done


    printf "%s\n" "${result[@]}"
}



registry_resolve_module()
{
    local module="$1"
    local array_name="$2"



    if ! registry_exists "${module}"; then

        log_error \
            "${REGISTRY_COMPONENT}" \
            "Модуль отсутствует: ${module}"

        return 1

    fi



    if [[ "${LSM_RESOLVING[$module]:-}" == "true" ]]; then

        log_error \
            "${REGISTRY_COMPONENT}" \
            "Обнаружен цикл зависимостей: ${module}"

        return 1

    fi



    LSM_RESOLVING["${module}"]="true"



    local deps

    deps="$(registry_dependencies "${module}")"



    for dep in ${deps}
    do

        registry_resolve_module \
            "${dep}" \
            "${array_name}" || return 1

    done



    LSM_RESOLVING["${module}"]=""



    eval "${array_name}+=(\"\${module}\")"
}
