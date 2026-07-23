#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Реестр модулей установки
# Путь: lib/installer/registry.sh
# ==============================================================================


set -Eeuo pipefail


[[ -n "${LSM_INSTALL_REGISTRY_LOADED:-}" ]] && return 0
readonly LSM_INSTALL_REGISTRY_LOADED=1



LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

LSM_MODULES_DIR="${LSM_MODULES_DIR:-${LSM_ROOT}/modules}"



declare -A LSM_MODULE_NAME
declare -A LSM_MODULE_DESCRIPTION
declare -A LSM_MODULE_VERSION
declare -A LSM_MODULE_CATEGORY
declare -A LSM_MODULE_DEPENDENCIES
declare -A LSM_MODULE_DEFAULT


declare -a LSM_MODULES=()



#
# Проверка регистрации
#

registry_exists()
{

    local module="$1"

    [[ -v "LSM_MODULE_NAME[$module]" ]]

}



#
# Добавление модуля
#

registry_add()
{

    local module="$1"


    [[ -n "${module}" ]] || return 1



    if registry_exists "${module}"; then

        return 0

    fi



    if ! module_has_manifest "${module}"; then

        log_warn \
        "Модуль ${module}: отсутствует manifest.conf"

        return 1

    fi



    if ! module_load_manifest "${module}"; then

        log_error \
        "Модуль ${module}: ошибка загрузки manifest"

        return 1

    fi



    LSM_MODULES+=("${module}")



    LSM_MODULE_NAME["${module}"]="${MODULE_NAME:-${module}}"

    LSM_MODULE_DESCRIPTION["${module}"]="${MODULE_DESCRIPTION:-}"

    LSM_MODULE_VERSION["${module}"]="${MODULE_VERSION:-unknown}"

    LSM_MODULE_CATEGORY["${module}"]="${MODULE_CATEGORY:-unknown}"

    LSM_MODULE_DEPENDENCIES["${module}"]="${MODULE_DEPENDENCIES:-}"

    LSM_MODULE_DEFAULT["${module}"]="${MODULE_DEFAULT:-no}"


}



#
# Сканирование всех модулей
#

registry_scan()
{

    LSM_MODULES=()

    unset LSM_MODULE_NAME
    unset LSM_MODULE_DESCRIPTION
    unset LSM_MODULE_VERSION
    unset LSM_MODULE_CATEGORY
    unset LSM_MODULE_DEPENDENCIES
    unset LSM_MODULE_DEFAULT


    declare -gA LSM_MODULE_NAME
    declare -gA LSM_MODULE_DESCRIPTION
    declare -gA LSM_MODULE_VERSION
    declare -gA LSM_MODULE_CATEGORY
    declare -gA LSM_MODULE_DEPENDENCIES
    declare -gA LSM_MODULE_DEFAULT



    [[ -d "${LSM_MODULES_DIR}" ]] || return 0



    while read -r module
    do

        [[ -z "${module}" ]] && continue

        registry_add "${module}"


    done < <(

        find "${LSM_MODULES_DIR}" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -printf "%f\n" \
        2>/dev/null | sort

    )

}



registry_load_default()
{

    registry_scan

}



#
# Список
#

registry_list()
{

    printf "%s\n" "${LSM_MODULES[@]}"

}



#
# Информация
#

registry_info()
{

    local module="$1"


    registry_exists "${module}" || return 1


cat <<EOF

Модуль: ${module}

Название:
${LSM_MODULE_NAME[$module]}

Описание:
${LSM_MODULE_DESCRIPTION[$module]}

Категория:
${LSM_MODULE_CATEGORY[$module]}

Версия:
${LSM_MODULE_VERSION[$module]}

Зависимости:
${LSM_MODULE_DEPENDENCIES[$module]:-нет}

По умолчанию:
${LSM_MODULE_DEFAULT[$module]}

EOF

}



#
# Зависимости
#

registry_dependencies()
{

    echo "${LSM_MODULE_DEPENDENCIES[$1]:-}"

}



#
# Проверка зависимостей
#

registry_check_dependencies()
{

    local module="$1"


    registry_exists "${module}" || return 1



    for dep in $(registry_dependencies "${module}")
    do

        if ! registry_exists "${dep}"; then

            log_error \
            "Модуль ${module}: отсутствует зависимость ${dep}"

            return 1

        fi

    done


}



#
# Resolver порядка установки
#

registry_resolve_order()
{

    local result=()


    for module in "$@"
    do

        registry_resolve_module "${module}" result

    done


    printf "%s\n" "${result[@]}"

}



registry_resolve_module()
{

    local module="$1"

    local -n output="$2"



    for item in "${output[@]}"
    do

        [[ "${item}" == "${module}" ]] && return

    done



    if ! registry_exists "${module}"; then

        log_error \
        "Модуль ${module} отсутствует в registry"

        return 1

    fi



    for dep in $(registry_dependencies "${module}")
    do

        registry_resolve_module "${dep}" output

    done



    output+=("${module}")

}
