#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Валидатор модулей
#
# Путь:
#   lib/installer/module_validator.sh
#
# Назначение:
#   Проверка структуры модулей и их manifest.conf перед установкой.
#
# ==============================================================================

set -Eeuo pipefail


[[ -n "${LSM_MODULE_VALIDATOR_LOADED:-}" ]] && return 0
readonly LSM_MODULE_VALIDATOR_LOADED=1


readonly VALIDATOR_COMPONENT="MODULE_VALIDATOR"



#
# Пути
#

LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

LSM_MODULES_DIR="${LSM_MODULES_DIR:-${LSM_ROOT}/modules}"



#
# Обязательные поля manifest.conf
#

readonly LSM_MANIFEST_REQUIRED_FIELDS=(
    "MODULE_ID"
    "MODULE_NAME"
    "MODULE_DESCRIPTION"
    "MODULE_VERSION"
    "MODULE_CATEGORY"
)



#
# Проверка каталога модуля
#

module_validate_files()
{
    local module="${1:-}"

    local module_dir="${LSM_MODULES_DIR}/${module}"



    if [[ ! -d "${module_dir}" ]]; then

        log_error \
            "${VALIDATOR_COMPONENT}" \
            "${module}: каталог отсутствует"

        return 1

    fi



    local required_files=(
        "manifest.conf"
        "install.sh"
    )



    local file


    for file in "${required_files[@]}"
    do

        if [[ ! -f "${module_dir}/${file}" ]]; then

            log_error \
                "${VALIDATOR_COMPONENT}" \
                "${module}: отсутствует обязательный файл ${file}"

            return 1

        fi

    done



    if [[ ! -x "${module_dir}/install.sh" ]]; then

        log_error \
            "${VALIDATOR_COMPONENT}" \
            "${module}: install.sh не имеет execute права"

        return 1

    fi



    return 0
}



#
# Проверка manifest.conf
#

module_validate_manifest()
{
    local module="${1:-}"



    if ! module_load_manifest "${module}"; then

        log_error \
            "${VALIDATOR_COMPONENT}" \
            "${module}: ошибка загрузки manifest.conf"

        return 1

    fi



    local field


    for field in "${LSM_MANIFEST_REQUIRED_FIELDS[@]}"
    do

        if [[ -z "${!field:-}" ]]; then

            log_error \
                "${VALIDATOR_COMPONENT}" \
                "${module}: отсутствует поле ${field}"

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
# Проверка зависимостей
#

module_validate_dependencies()
{
    local module="${1:-}"



    if ! module_load_manifest "${module}"; then

        return 1

    fi



    local dependencies="${MODULE_DEPENDENCIES:-}"



    [[ -z "${dependencies}" ]] && return 0



    local dependency


    for dependency in ${dependencies}
    do

        if ! registry_exists "${dependency}"; then

            log_error \
                "${VALIDATOR_COMPONENT}" \
                "${module}: отсутствует зависимость ${dependency}"

            return 1

        fi

    done



    return 0
}



#
# Проверка необязательных файлов
#

module_validate_optional_files()
{
    local module="${1:-}"

    local module_dir="${LSM_MODULES_DIR}/${module}"



    if [[ -f "${module_dir}/uninstall.sh" ]]; then

        if [[ ! -x "${module_dir}/uninstall.sh" ]]; then

            log_warn \
                "${VALIDATOR_COMPONENT}" \
                "${module}: uninstall.sh существует, но нет execute права"

        fi

    fi



    return 0
}



#
# Полная проверка модуля
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

    module_validate_optional_files "${module}" || return 1



    log_success \
        "${VALIDATOR_COMPONENT}" \
        "${module}: OK"



    return 0
}



#
# Проверка всех модулей
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
            "Ошибок проверки модулей: ${failed}"

        return 1

    fi



    log_success \
        "${VALIDATOR_COMPONENT}" \
        "Все модули прошли проверку"



    return 0
}
