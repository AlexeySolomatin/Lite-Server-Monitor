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
# Пути
#

LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

LSM_MODULES_DIR="${LSM_MODULES_DIR:-${LSM_ROOT}/modules}"

LSM_STATE_DIR="${LSM_STATE_DIR:-/var/lib/lsm}"

LSM_MODULE_STATE_DIR="${LSM_MODULE_STATE_DIR:-${LSM_STATE_DIR}/modules}"



#
# Проверка существования
#

modules_exists()
{

    local module="${1:-}"


    [[ -n "${module}" ]] || return 1


    [[ -d "${LSM_MODULES_DIR}/${module}" ]]

}



#
# Путь модуля
#

modules_path()
{

    echo "${LSM_MODULES_DIR}/${1}"

}



#
# Проверка состояния
#

modules_is_installed()
{

    [[ -f "${LSM_MODULE_STATE_DIR}/${1}.installed" ]]

}



#
# Сохранение состояния
#

modules_mark_installed()
{

    local module="$1"


    mkdir -p "${LSM_MODULE_STATE_DIR}"



    local version="unknown"



    if declare -f module_get_version >/dev/null 2>&1; then

        version=$(module_get_version "${module}")

    fi



    cat > "${LSM_MODULE_STATE_DIR}/${module}.installed" <<EOF
MODULE=${module}
VERSION=${version}
DATE=$(date '+%Y-%m-%d %H:%M:%S')
EOF

}



#
# Установка модуля
#

modules_install()
{

    local module="${1:-}"



    if [[ -z "${module}" ]]; then

        log_error "Имя модуля не указано."

        return 1

    fi



    if ! modules_exists "${module}"; then

        log_error \
            "Модуль отсутствует: ${module}"

        return 1

    fi



    #
    # Проверка валидности
    #

    if declare -f module_validate_all >/dev/null 2>&1; then


        if ! module_validate_all "${module}"; then

            log_error \
                "Модуль ${module} не прошел проверку."

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
        "Установка модуля: ${module}"



    #
    # Загрузка метаданных
    #

    if declare -f module_load_manifest >/dev/null 2>&1; then

        module_load_manifest "${module}"

        log_info \
            "Версия модуля: ${MODULE_VERSION:-unknown}"

    fi



    #
    # Запуск установки
    #

    if [[ ! -x "${module_dir}/install.sh" ]]; then

        log_error \
            "Отсутствует install.sh: ${module}"

        return 1

    fi



    if ! "${module_dir}/install.sh"; then

        log_error \
            "Ошибка установки модуля: ${module}"

        return 1

    fi



    modules_mark_installed "${module}"



    log_success \
        "Модуль ${module} установлен."

}



#
# Удаление
#

modules_remove()
{

    local module="${1:-}"



    if ! modules_exists "${module}"; then

        log_error \
            "Модуль отсутствует: ${module}"

        return 1

    fi



    local module_dir

    module_dir="$(modules_path "${module}")"



    if [[ -x "${module_dir}/uninstall.sh" ]]; then

        log_info \
            "Удаление модуля: ${module}"


        "${module_dir}/uninstall.sh"

    fi



    rm -f \
        "${LSM_MODULE_STATE_DIR}/${module}.installed"



    log_success \
        "Модуль ${module} удален."

}



#
# Включение
#

modules_enable()
{

    local module="$1"

    local script

    script="$(modules_path "${module}")/enable.sh"



    if [[ -x "${script}" ]]; then

        "${script}"

    else

        log_warn \
            "enable.sh отсутствует: ${module}"

    fi

}



#
# Отключение
#

modules_disable()
{

    local module="$1"

    local script

    script="$(modules_path "${module}")/disable.sh"



    if [[ -x "${script}" ]]; then

        "${script}"

    else

        log_warn \
            "disable.sh отсутствует: ${module}"

    fi

}



#
# Статус
#

modules_status()
{

    local module="$1"



    echo



    if modules_is_installed "${module}"; then


        echo "Модуль: ${module}"

        echo "Состояние: установлен"

        echo


        cat \
        "${LSM_MODULE_STATE_DIR}/${module}.installed"



    else


        echo "Модуль: ${module}"

        echo "Состояние: не установлен"


    fi



    echo

}



#
# Список установленных
#

modules_installed_list()
{

    [[ -d "${LSM_MODULE_STATE_DIR}" ]] || return 0



    {
        find "${LSM_MODULE_STATE_DIR}" \
            -name "*.installed" \
            -printf "%f\n" \
            2>/dev/null || true

    } | sed 's/\.installed$//'

}
