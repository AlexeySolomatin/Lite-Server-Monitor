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
# Paths
#

LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

LSM_MODULES_DIR="${LSM_MODULES_DIR:-${LSM_ROOT}/modules}"



#
# Required manifest fields
#

readonly LSM_MANIFEST_REQUIRED_FIELDS=(
    "MODULE_ID"
    "MODULE_NAME"
    "MODULE_DESCRIPTION"
    "MODULE_VERSION"
    "MODULE_CATEGORY"
)



#
# Validate module files
#

module_validate_files()
{

    local module="$1"

    local module_dir="${LSM_MODULES_DIR}/${module}"



    local required_files=(
        "manifest.conf"
        "install.sh"
    )



    for file in "${required_files[@]}"
    do

        if [[ ! -f "${module_dir}/${file}" ]]; then

            log_error \
                "Модуль ${module}: отсутствует обязательный файл ${file}"

            return 1

        fi

    done



    return 0

}



#
# Validate manifest
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



    for field in "${LSM_MANIFEST_REQUIRED_FIELDS[@]}"
    do

        if [[ -z "${!field:-}" ]]; then

            log_error \
                "Модуль ${module}: отсутствует поле ${field}"

            errors=$((errors+1))

        fi

    done



    return "${errors}"

}



#
# Validate dependencies
#

module_validate_dependencies()
{

    local module="$1"



    if ! module_load_manifest "${module}"; then

        log_error \
            "Модуль ${module}: невозможно проверить зависимости"

        return 1

    fi



    local dependencies="${MODULE_DEPENDENCIES:-}"



    [[ -z "${dependencies}" ]] && return 0



    for dependency in ${dependencies}
    do

        if ! declare -f module_has_manifest >/dev/null 2>&1; then

            log_error \
                "API module_loader недоступен"

            return 1

        fi



        if ! module_has_manifest "${dependency}"; then

            log_error \
                "Модуль ${module}: отсутствует зависимость ${dependency}"

            return 1

        fi

    done



    return 0

}



#
# Full module validation
#

module_validate_all()
{

    local module="$1"



    log_info \
        "Проверка модуля: ${module}"



    module_validate_files "${module}" || return 1


    module_validate_manifest "${module}" || return 1


    module_validate_dependencies "${module}" || return 1



    log_success \
        "Модуль ${module}: OK"



    return 0

}



#
# Validate all modules
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



    done < <(
        module_loader_list
    )



    if [[ "${failed}" -gt 0 ]]; then

        log_error \
            "Ошибок модулей: ${failed}"

        return 1

    fi



    log_success \
        "Все модули прошли проверку"



    return 0

}
