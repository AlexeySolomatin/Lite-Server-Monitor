#!/usr/bin/env bash
#
# ==============================================================================
# Lite Server Monitor (LSM)
# Реестр компонентов установки
# Путь: lib/installer/registry.sh
# ==============================================================================


set -Eeuo pipefail


[[ -n "${LSM_INSTALL_REGISTRY_LOADED:-}" ]] && return 0
readonly LSM_INSTALL_REGISTRY_LOADED=1


#
# Пути
#

LSM_MODULES_DIR="${LSM_MODULES_DIR:-${LSM_ROOT}/modules}"


#
# Внутреннее хранилище реестра
#

declare -A LSM_MODULE_TITLE
declare -A LSM_MODULE_DESCRIPTION
declare -A LSM_MODULE_CATEGORY
declare -A LSM_MODULE_VERSION
declare -A LSM_MODULE_DEPENDS
declare -A LSM_MODULE_DEFAULT


declare -a LSM_MODULES=()


#
# Добавление модуля в реестр
#
registry_add()
{
    local module="$1"

    [[ -n "${module}" ]] || return 1


    local manifest="${LSM_MODULES_DIR}/${module}/manifest.conf"


    if [[ ! -f "${manifest}" ]]; then

        log_warn \
        "Отсутствует manifest.conf для модуля ${module}"

        return 1

    fi


    unset MODULE_NAME
    unset MODULE_TITLE
    unset MODULE_DESCRIPTION
    unset MODULE_CATEGORY
    unset MODULE_VERSION
    unset MODULE_DEPENDS
    unset MODULE_DEFAULT_ENABLED


    # shellcheck source=/dev/null
    source "${manifest}"


    LSM_MODULES+=("${module}")


    LSM_MODULE_TITLE["${module}"]="${MODULE_TITLE:-${module}}"

    LSM_MODULE_DESCRIPTION["${module}"]="${MODULE_DESCRIPTION:-}"

    LSM_MODULE_CATEGORY["${module}"]="${MODULE_CATEGORY:-unknown}"

    LSM_MODULE_VERSION["${module}"]="${MODULE_VERSION:-1.0.0}"

    LSM_MODULE_DEPENDS["${module}"]="${MODULE_DEPENDS:-}"

    LSM_MODULE_DEFAULT["${module}"]="${MODULE_DEFAULT_ENABLED:-no}"

}



#
# Сканирование всех модулей
#
registry_scan()
{

    LSM_MODULES=()


    if [[ ! -d "${LSM_MODULES_DIR}" ]]; then

        return 0

    fi



    while read -r module
    do

        registry_add "${module}"


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
# Загрузка реестра
#
registry_load_default()
{
    registry_scan
}



#
# Проверка существования
#
registry_exists()
{
    local module="$1"


    for item in "${LSM_MODULES[@]}"
    do

        [[ "${item}" == "${module}" ]] && return 0

    done


    return 1
}



#
# Список модулей
#
registry_list()
{

    printf "%s\n" "${LSM_MODULES[@]}"

}



#
# Информация о модуле
#
registry_info()
{

    local module="$1"


    if ! registry_exists "${module}"; then

        return 1

    fi


    echo
    echo "Модуль: ${module}"
    echo "Название: ${LSM_MODULE_TITLE[$module]}"
    echo "Описание: ${LSM_MODULE_DESCRIPTION[$module]}"
    echo "Категория: ${LSM_MODULE_CATEGORY[$module]}"
    echo "Версия: ${LSM_MODULE_VERSION[$module]}"
    echo "Зависимости: ${LSM_MODULE_DEPENDS[$module]}"
    echo "По умолчанию: ${LSM_MODULE_DEFAULT[$module]}"
    echo

}



#
# Получить зависимости модуля
#
registry_dependencies()
{

    local module="$1"


    echo "${LSM_MODULE_DEPENDS[$module]:-}"

}



#
# Проверка зависимостей
#
registry_check_dependencies()
{

    local module="$1"


    if ! registry_exists "${module}"; then

        log_error \
        "Модуль ${module} отсутствует в реестре."

        return 1

    fi



    local dependencies

    dependencies=$(registry_dependencies "${module}")



    [[ -z "${dependencies}" ]] && return 0



    for dependency in ${dependencies}
    do

        if ! registry_exists "${dependency}"; then

            log_error \
            "Модуль ${module} требует отсутствующий компонент ${dependency}"

            return 1

        fi

    done


}



#
# Получение порядка установки
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
# Рекурсивное разрешение зависимостей
#
registry_resolve_module()
{

    local module="$1"

    local -n output="$2"



    for item in "${output[@]}"
    do

        [[ "${item}" == "${module}" ]] && return

    done



    local dependencies

    dependencies=$(registry_dependencies "${module}")



    for dependency in ${dependencies}
    do

        registry_resolve_module \
            "${dependency}" \
            output

    done



    output+=("${module}")

}
