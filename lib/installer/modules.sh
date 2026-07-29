#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Библиотека управления модулями
# Путь: lib/installer/modules.sh
# ==============================================================================

set -Eeuo pipefail


[[ -n "${LSM_MODULES_LOADED:-}" ]] && return 0
readonly LSM_MODULES_LOADED=1


#
# Компонент логирования
#

readonly MODULES_COMPONENT="MODULES"



#
# Пути
#

if [[ -z "${LSM_ROOT:-}" ]]; then
    LSM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

export LSM_ROOT


LSM_MODULES_DIR="${LSM_MODULES_DIR:-${LSM_ROOT}/modules}"
LSM_STATE_DIR="${LSM_STATE_DIR:-/var/lib/lsm}"
LSM_MODULE_STATE_DIR="${LSM_MODULE_STATE_DIR:-${LSM_STATE_DIR}/modules}"



#
# Проверка существования модуля
#

modules_exists()
{
    local module="${1:-}"

    [[ -n "${module}" ]] || return 1

    [[ -d "${LSM_MODULES_DIR}/${module}" ]]
}



#
# Путь к модулю
#

modules_path()
{
    local module="${1:-}"

    [[ -n "${module}" ]] || return 1

    printf "%s\n" \
        "${LSM_MODULES_DIR}/${module}"
}



#
# Работа с состоянием
#

modules_is_installed()
{
    local module="${1:-}"

    [[ -f "${LSM_MODULE_STATE_DIR}/${module}.installed" ]]
}



modules_mark_installed()
{
    local module="${1:-}"

    mkdir -p "${LSM_MODULE_STATE_DIR}"

    chmod 750 "${LSM_MODULE_STATE_DIR}"

    date '+%Y-%m-%d %H:%M:%S' \
        > "${LSM_MODULE_STATE_DIR}/${module}.installed"

    chmod 640 \
        "${LSM_MODULE_STATE_DIR}/${module}.installed"
}



modules_clear_state()
{
    local module="${1:-}"

    rm -f \
        "${LSM_MODULE_STATE_DIR}/${module}.installed"
}



#
# Установка модуля
#

modules_install()
{
    local module="${1:-}"

    if [[ -z "${module}" ]]; then
        log_error "${MODULES_COMPONENT}" \
            "Имя модуля не указано."
        return 1
    fi


    if ! modules_exists "${module}"; then
        log_error "${MODULES_COMPONENT}" \
            "Модуль не найден: ${module}"
        return 1
    fi


    if modules_is_installed "${module}"; then
        log_warn "${MODULES_COMPONENT}" \
            "Модуль уже установлен: ${module}"
        return 0
    fi


    local module_dir
    module_dir="$(modules_path "${module}")"


    local installer="${module_dir}/install.sh"


    if [[ ! -f "${installer}" ]]; then
        log_error "${MODULES_COMPONENT}" \
            "install.sh отсутствует: ${module}"
        return 1
    fi


    chmod +x "${installer}"


    log_info "${MODULES_COMPONENT}" \
        "Установка модуля: ${module}"


    if ! bash "${installer}"; then

        log_error "${MODULES_COMPONENT}" \
            "Ошибка установки модуля: ${module}"

        return 1
    fi


    modules_mark_installed "${module}"


    log_success "${MODULES_COMPONENT}" \
        "Модуль установлен: ${module}"

    return 0
}



#
# Удаление модуля
#

modules_remove()
{
    local module="${1:-}"


    if [[ -z "${module}" ]]; then
        log_error "${MODULES_COMPONENT}" \
            "Имя модуля не указано."
        return 1
    fi


    if ! modules_exists "${module}"; then
        log_error "${MODULES_COMPONENT}" \
            "Модуль не найден: ${module}"
        return 1
    fi


    local module_dir
    module_dir="$(modules_path "${module}")"


    local uninstall="${module_dir}/uninstall.sh"



    if [[ -f "${uninstall}" ]]; then

        chmod +x "${uninstall}"


        log_info "${MODULES_COMPONENT}" \
            "Удаление модуля: ${module}"


        if ! bash "${uninstall}"; then

            log_error "${MODULES_COMPONENT}" \
                "Ошибка удаления модуля: ${module}"

            return 1
        fi

    else

        log_warn "${MODULES_COMPONENT}" \
            "uninstall.sh отсутствует: ${module}"

    fi



    modules_clear_state "${module}"


    log_success "${MODULES_COMPONENT}" \
        "Модуль удален: ${module}"

    return 0
}



#
# Включение модуля
#

modules_enable()
{
    local module="${1:-}"


    if [[ -z "${module}" ]]; then
        log_error "${MODULES_COMPONENT}" \
            "Имя модуля не указано."
        return 1
    fi


    local module_dir
    module_dir="$(modules_path "${module}")"



    if [[ ! -x "${module_dir}/enable.sh" ]]; then

        log_warn "${MODULES_COMPONENT}" \
            "enable.sh отсутствует: ${module}"

        return 1
    fi



    log_info "${MODULES_COMPONENT}" \
        "Включение модуля: ${module}"



    if "${module_dir}/enable.sh"; then

        log_success "${MODULES_COMPONENT}" \
            "Модуль включен: ${module}"

    else

        log_error "${MODULES_COMPONENT}" \
            "Ошибка включения модуля: ${module}"

        return 1

    fi
}



#
# Отключение модуля
#

modules_disable()
{
    local module="${1:-}"


    if [[ -z "${module}" ]]; then
        log_error "${MODULES_COMPONENT}" \
            "Имя модуля не указано."
        return 1
    fi


    local module_dir
    module_dir="$(modules_path "${module}")"



    if [[ ! -x "${module_dir}/disable.sh" ]]; then

        log_warn "${MODULES_COMPONENT}" \
            "disable.sh отсутствует: ${module}"

        return 1
    fi



    log_info "${MODULES_COMPONENT}" \
        "Отключение модуля: ${module}"



    if "${module_dir}/disable.sh"; then

        log_success "${MODULES_COMPONENT}" \
            "Модуль отключен: ${module}"

    else

        log_error "${MODULES_COMPONENT}" \
            "Ошибка отключения модуля: ${module}"

        return 1

    fi
}



#
# Статус модуля
#

modules_status()
{
    local module="${1:-}"


    if [[ -z "${module}" ]]; then

        log_error "${MODULES_COMPONENT}" \
            "Имя модуля не указано."

        return 1
    fi



    if modules_is_installed "${module}"; then

        log_info "${MODULES_COMPONENT}" \
            "Модуль установлен: ${module}"

        printf "Дата установки: "

        cat \
            "${LSM_MODULE_STATE_DIR}/${module}.installed"

    else

        log_warn "${MODULES_COMPONENT}" \
            "Модуль не установлен: ${module}"

    fi
}



#
# Список установленных модулей
#

modules_installed_list()
{
    [[ -d "${LSM_MODULE_STATE_DIR}" ]] || return 0


    find "${LSM_MODULE_STATE_DIR}" \
        -name "*.installed" \
        -printf "%f\n" \
        | sed 's/\.installed$//'
}
