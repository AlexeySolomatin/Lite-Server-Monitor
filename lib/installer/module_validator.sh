#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Module Validator API v1.3
# Path: lib/installer/module_validator.sh
# ==============================================================================

set -Eeuo pipefail


[[ -n "${LSM_MODULE_VALIDATOR_LOADED:-}" ]] && return 0
readonly LSM_MODULE_VALIDATOR_LOADED=1


readonly VALIDATOR_COMPONENT="MODULE_VALIDATOR"


LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

LSM_MODULES_DIR="${LSM_MODULES_DIR:-${LSM_ROOT}/modules}"



readonly LSM_MANIFEST_REQUIRED_FIELDS=(
    "MODULE_ID"
    "MODULE_NAME"
    "MODULE_DESCRIPTION"
    "MODULE_VERSION"
    "MODULE_CATEGORY"
)



#
# Validate directory and files
#

module_validate_files()
{
    local module="${1:-}"

    local module_dir="${LSM_MODULES_DIR}/${module}"


    if [[ ! -d "${module_dir}" ]]; then

        log_error \
            "${VALIDATOR_COMPONENT}" \
            "Каталог отсутствует: ${module}"

        return 1
    fi


    local file


    for file in manifest.conf install.sh
    do

        if [[ ! -f "${module_dir}/${file}" ]]; then

            log_error \
                "${VALIDATOR_COMPONENT}" \
                "${module}: отсутствует ${file}"

            return 1

        fi

    done



    if [[ ! -x "${module_dir}/install.sh" ]]; then

        log_warn \
            "${VALIDATOR_COMPONENT}" \
            "${module}: install.sh не имеет execute права"

        chmod +x "${module_dir}/install.sh"

    fi


    return 0
}



#
# Validate manifest
#

module_validate_manifest()
{
    local module="${1:-}"


    if ! module_load_manifest "${module}"; then

        log_error \
            "${VALIDATOR_COMPONENT}" \
            "${module}: manifest не загружен"

        return 1

    fi



    local field


    for field in "${LSM_MANIFEST_REQUIRED_FIELDS[@]}"
    do

        if [[ -z "${!field:-}" ]]; then

            log_error \
                "${VALIDATOR_COMPONENT}" \
                "${module}: отсутствует ${field}"

            return 1

        fi

    done



    if [[ "${MODULE_ID}" != "${module}" ]]; then

        log_error \
            "${VALIDATOR_COMPONENT}" \
            "${module}: MODULE_ID=${MODULE_ID}, ожидался ${module}"

        return 1

    fi



    return 0
}



#
# Validate dependencies
#

module_validate_dependencies()
{
    local module="${1:-}"


    module_load_manifest "${module}" || return 1


    local dependency


    for dependency in ${MODULE_DEPENDENCIES:-}
    do

        if ! registry_exists "${dependency}"; then

            log_error \
                "${VALIDATOR_COMPONENT}" \
                "${module}: зависимость отсутствует ${dependency}"

            return 1

        fi

    done


    return 0
}



#
# Full validation
#

module_validate_all()
{
    local module="${1:-}"


    log_info \
        "${VALIDATOR_COMPONENT}" \
        "Проверка модуля: ${module}"


    module_validate_files "${module}" || return 1

    module_validate_manifest "${module}" || return 1

    module_validate_dependencies "${module}" || return 1


    log_success \
        "${VALIDATOR_COMPONENT}" \
        "${module}: OK"


    return 0
}



#
# Validate all
#

module_validate_all_modules()
{
    local failed=0
    local module


    while read -r module
    do

        [[ -z "${module}" ]] && continue


        if ! module_validate_all "${module}"; then

            failed=$((failed+1))

        fi


    done < <(
        module_loader_list
    )



    if (( failed > 0 )); then

        log_error \
            "${VALIDATOR_COMPONENT}" \
            "Ошибок: ${failed}"

        return 1

    fi



    log_success \
        "${VALIDATOR_COMPONENT}" \
        "Все модули корректны"


    return 0
}
