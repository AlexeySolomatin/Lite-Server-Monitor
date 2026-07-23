#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Валидатор модулей
# Путь: lib/installer/module_validator.sh
# ==============================================================================


set -Eeuo pipefail


[[ -n "${LSM_MODULE_VALIDATOR_LOADED:-}" ]] && return 0
readonly LSM_MODULE_VALIDATOR_LOADED=1



#
# Пути
#

LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

LSM_MODULES_DIR="${LSM_MODULES_DIR:-${LSM_ROOT}/modules}"



#
# Проверка структуры модуля
#

module_validate_files()
{

    local module="$1"

    local module_dir="${LSM_MODULES_DIR}/${module}"



    local required_files=(
        "manifest.conf"
        "install.sh"
        "uninstall.sh"
    )



    for file in "${required_files[@]}"
    do

        if [[ ! -f "${module_dir}/${file}" ]]; then

            log_error \
                "Модуль ${module}: отсутствует файл ${file}"

            return 1

        fi

    done



    return 0

}



#
# Проверка исполняемых файлов
#

module_validate_permissions()
{

    local module="$1"

    local module_dir="${LSM_MODULES_DIR}/${module}"



    local scripts=(
        "install.sh"
        "uninstall.sh"
    )



    for script in "${scripts[@]}"
    do

        if [[ ! -x "${module_dir}/${script}" ]]; then

            log_warn \
                "Модуль ${module}: ${script} не имеет права выполнения"

        fi

    done


    return 0

}



#
# Проверка manifest.conf
#

module_validate_manifest()
{

    local module="$1"



    if ! module_load_manifest "${module}"; then

        log_error \
            "Модуль ${module}: manifest.conf не загружен"

        return 1

    fi



    local errors=0



    if [[ "${MODULE_ID:-}" != "${module}" ]]; then

        log_error \
            "Модуль ${module}: MODULE_ID (${MODULE_ID:-empty}) не совпадает с именем каталога"

        errors=$((errors+1))

    fi



    local required_fields=(
        "MODULE_NAME"
        "MODULE_DESCRIPTION"
        "MODULE_VERSION"
        "MODULE_CATEGORY"
    )



    for field in "${required_fields[@]}"
    do

        if [[ -z "${!field:-}" ]]; then

            log_error \
                "Модуль ${module}: отсутствует ${field}"

            errors=$((errors+1))

        fi

    done



    return "${errors}"

}



#
# Проверка зависимостей
#

module_validate_dependencies()
{

    local module="$1"



    module_load_manifest "${module}" || return 1



    if [[ -z "${MODULE_DEPENDENCIES:-}" ]]; then

        return 0

    fi



    for dependency in ${MODULE_DEPENDENCIES}
    do

        if [[ ! -d "${LSM_MODULES_DIR}/${dependency}" ]]; then

            log_error \
                "Модуль ${module}: отсутствует зависимость ${dependency}"

            return 1

        fi

    done



    return 0

}



#
# Полная проверка
#

module_validate_all()
{

    local module="$1"



    log_info \
        "Проверка модуля: ${module}"



    module_validate_files "${module}" || return 1

    module_validate_manifest "${module}" || return 1

    module_validate_dependencies "${module}" || return 1

    module_validate_permissions "${module}" || return 1



    log_success \
        "Модуль ${module} корректен"



    return 0

}



#
# Проверка всех модулей
#

module_validate_all_modules()
{

    local failed=0



    while read -r module
    do

        [[ -z "${module}" ]] && continue


        if ! module_validate_all "${module}"; then

            failed=$((failed+1))

        fi


    done < <(module_loader_list)



    if [[ "${failed}" -gt 0 ]]; then

        log_error \
            "Найдено проблемных модулей: ${failed}"

        return 1

    fi



    log_success \
        "Все модули прошли проверку"


    return 0

}
