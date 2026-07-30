#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Validator модулей
# Путь: lib/installer/module_validator.sh
# Версия: 1.2
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
# Обязательные поля manifest
#

readonly LSM_MANIFEST_REQUIRED_FIELDS=(
    "MODULE_ID"
    "MODULE_NAME"
    "MODULE_DESCRIPTION"
    "MODULE_VERSION"
    "MODULE_CATEGORY"
)



#
# Проверка существования модуля
#

module_validate_exists()
{
    local module="${1:-}"

    local module_dir="${LSM_MODULES_DIR}/${module}"


    if [[ ! -d "${module_dir}" ]]; then

        log_error \
            "Модуль не существует: ${module}"

        return 1

    fi


    return 0
}



#
# Проверка файлов модуля
#

module_validate_files()
{
    local module="${1:-}"

    local module_dir="${LSM_MODULES_DIR}/${module}"



    local required_files=(
        "manifest.conf"
        "install.sh"
    )



    local file


    for file in "${required_files[@]}"
    do

        if [[ ! -f "${module_dir}/${file}" ]]; then

            log_error \
                "Модуль ${module}: отсутствует файл ${file}"

            return 1

        fi

    done



    #
    # Проверяем install.sh
    #

    if [[ ! -r "${module_dir}/install.sh" ]]; then

        log_error \
            "Модуль ${module}: install.sh недоступен для чтения"

        return 1

    fi



    if [[ ! -x "${module_dir}/install.sh" ]]; then

        log_warn \
            "Модуль ${module}: install.sh не имеет execute bit"

    fi



    return 0
}



#
# Базовая защита manifest
#

module_validate_manifest_security()
{
    local module="${1:-}"

    local manifest="${LSM_MODULES_DIR}/${module}/manifest.conf"



    if grep -Eq \
        '(^|[[:space:]])(rm|chmod|chown|curl|wget|apt|apt-get|systemctl)[[:space:]]|[;&|`$()]' \
        "${manifest}"
    then

        log_error \
            "Модуль ${module}: manifest содержит потенциально опасный код"

        return 1

    fi



    return 0
}



#
# Проверка manifest
#

module_validate_manifest()
{
    local module="${1:-}"



    if ! module_validate_manifest_security "${module}"; then
        return 1
    fi



    if ! module_load_manifest "${module}"; then

        log_error \
            "Модуль ${module}: ошибка загрузки manifest.conf"

        return 1

    fi



    local errors=0

    local field



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
# Полная проверка модуля
#

module_validate_all()
{
    local module="${1:-}"



    log_info \
        "Проверка модуля: ${module}"



    module_validate_exists "${module}" || return 1


    module_validate_files "${module}" || return 1


    module_validate_manifest "${module}" || return 1



    log_success \
        "Модуль ${module}: проверка успешно пройдена"



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


    done < <(
        module_loader_list
    )



    if (( failed > 0 )); then

        log_error \
            "Ошибок проверки модулей: ${failed}"

        return 1

    fi



    log_success \
        "Все модули прошли проверку"



    return 0
}
