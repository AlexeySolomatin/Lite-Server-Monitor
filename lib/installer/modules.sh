#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Библиотека управления модулями
# Путь: lib/installer/modules.sh
# ==============================================================================


set -Eeuo pipefail


#
# Защита от повторной загрузки
#

[[ -n "${LSM_MODULES_LOADED:-}" ]] && return 0
readonly LSM_MODULES_LOADED=1



#
# Пути
#

LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

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
# Получение пути модуля
#

modules_path()
{

    local module="$1"


    echo "${LSM_MODULES_DIR}/${module}"

}



#
# Проверка установленного состояния
#

modules_is_installed()
{

    local module="$1"


    [[ -f "${LSM_MODULE_STATE_DIR}/${module}.installed" ]]

}



#
# Создание состояния
#

modules_mark_installed()
{

    local module="$1"


    mkdir -p "${LSM_MODULE_STATE_DIR}"


    date '+%Y-%m-%d %H:%M:%S' \
        > "${LSM_MODULE_STATE_DIR}/${module}.installed"

}



#
# Установка модуля
#

modules_install()
{

    local module="${1:-}"



    if [[ -z "${module}" ]]; then

        log_error "Не указано имя модуля."

        return 1

    fi



    if ! modules_exists "${module}"; then

        log_error \
        "Модуль '${module}' не найден."

        return 1

    fi



    #
    # Проверка зависимостей
    #

    if declare -f registry_check_dependencies >/dev/null 2>&1; then


        if ! registry_check_dependencies "${module}"; then

            log_error \
            "Не выполнены зависимости модуля ${module}"

            return 1

        fi

    fi



    #
    # Повторная установка
    #

    if modules_is_installed "${module}"; then

        log_warn \
        "Модуль ${module} уже установлен."

        return 0

    fi



    local module_dir

    module_dir="$(modules_path "${module}")"



    log_info \
    "Установка модуля ${module}"



    #
    # Запуск install.sh
    #

    if [[ -x "${module_dir}/install.sh" ]]; then


        "${module_dir}/install.sh"


    else


        log_warn \
        "install.sh отсутствует для ${module}"


    fi



    modules_mark_installed "${module}"



    log_success \
    "Модуль ${module} установлен."

}



#
# Удаление модуля
#

modules_remove()
{

    local module="${1:-}"



    if ! modules_exists "${module}"; then

        log_error \
        "Модуль ${module} отсутствует."

        return 1

    fi



    local module_dir

    module_dir="$(modules_path "${module}")"



    if [[ -x "${module_dir}/uninstall.sh" ]]; then


        log_info \
        "Удаление модуля ${module}"


        "${module_dir}/uninstall.sh"


    fi



    rm -f \
    "${LSM_MODULE_STATE_DIR}/${module}.installed"



    log_success \
    "Модуль ${module} удален."

}



#
# Включение модуля
#

modules_enable()
{

    local module="$1"


    local module_dir

    module_dir="$(modules_path "${module}")"



    if [[ -x "${module_dir}/enable.sh" ]]; then


        "${module_dir}/enable.sh"


    else


        log_warn \
        "enable.sh отсутствует для ${module}"


    fi

}



#
# Отключение модуля
#

modules_disable()
{

    local module="$1"


    local module_dir

    module_dir="$(modules_path "${module}")"



    if [[ -x "${module_dir}/disable.sh" ]]; then


        "${module_dir}/disable.sh"


    else


        log_warn \
        "disable.sh отсутствует для ${module}"


    fi

}



#
# Статус модуля
#

modules_status()
{

    local module="$1"


    echo


    if modules_is_installed "${module}"; then

        echo "Модуль: ${module}"

        echo "Состояние: установлен"


        if [[ -f "${LSM_MODULE_STATE_DIR}/${module}.installed" ]]; then

            echo "Дата:"
            cat "${LSM_MODULE_STATE_DIR}/${module}.installed"

        fi


    else


        echo "Модуль: ${module}"

        echo "Состояние: не установлен"


    fi


    echo

}



#
# Список установленных модулей
#

modules_installed_list()
{

    if [[ ! -d "${LSM_MODULE_STATE_DIR}" ]]; then

        return 0

    fi


    find "${LSM_MODULE_STATE_DIR}" \
        -name "*.installed" \
        -printf "%f\n" \
        | sed 's/.installed$//'

}
