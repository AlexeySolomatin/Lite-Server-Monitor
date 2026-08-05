#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Module API v1.1
#
# Путь:
#   lib/core/module_api.sh
#
# Назначение:
#   Единый интерфейс взаимодействия ядра LSM
#   с модулями мониторинга.
#
# Поддерживаемый контракт модулей:
#
#   check.sh status
#       Краткий статус
#
#   check.sh report
#       Подробный отчет
#
#   check.sh check
#       Машинная проверка
#
#
# Коды возврата:
#
#   0 - OK
#   1 - WARN
#   2 - FAIL
#   3 - ERROR
#
# ==============================================================================


set -Eeuo pipefail



#
# Защита от повторной загрузки
#

[[ -n "${LSM_MODULE_API_LOADED:-}" ]] && return 0

readonly LSM_MODULE_API_LOADED=1



readonly MODULE_API_COMPONENT="MODULE_API"



#
# Статусы модулей
#

readonly MODULE_STATUS_OK=0
readonly MODULE_STATUS_WARN=1
readonly MODULE_STATUS_FAIL=2
readonly MODULE_STATUS_ERROR=3



#
# Пути
#

LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

LSM_MODULES_DIR="${LSM_MODULES_DIR:-${LSM_ROOT}/modules}"

LSM_STATE_DIR="${LSM_STATE_DIR:-/var/lib/lsm}"

LSM_MODULE_STATE_DIR="${LSM_MODULE_STATE_DIR:-${LSM_STATE_DIR}/modules}"



#
# Загрузка UI если доступен
#

if [[ -f "${LSM_ROOT}/lib/core/ui.sh" ]]; then

    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/core/ui.sh"

fi



#
# Fallback UI
#

if ! declare -f ui_ok >/dev/null 2>&1; then

    ui_ok()
    {
        echo "[ OK   ] $*"
    }


    ui_warn()
    {
        echo "[ WARN ] $*"
    }


    ui_fail()
    {
        echo "[ FAIL ] $*"
    }


    ui_error()
    {
        echo "[ERROR ] $*"
    }

fi



#
# Получение списка установленных модулей
#

module_api_list_installed()
{

    if declare -f modules_installed_list >/dev/null 2>&1; then

        modules_installed_list

        return 0

    fi



    [[ -d "${LSM_MODULE_STATE_DIR}" ]] || return 0



    find "${LSM_MODULE_STATE_DIR}" \
        -name "*.installed" \
        -type f \
        -printf "%f\n" \
        2>/dev/null \
        | sed 's/\.installed$//' \
        | sort

}



#
# Проверка существования модуля
#

module_api_exists()
{
    local module="${1:-}"


    [[ -n "${module}" ]] || return 1


    [[ -d "${LSM_MODULES_DIR}/${module}" ]]
}



#
# Получение каталога модуля
#

module_api_path()
{
    local module="${1:-}"


    module_api_exists "${module}" || return 1


    printf "%s\n" \
        "${LSM_MODULES_DIR}/${module}"
}



#
# Поиск check-скрипта
#

module_api_get_check_script()
{
    local module="${1:-}"


    local module_dir

    module_dir="$(module_api_path "${module}")" \
        || return 1



    local script



    #
    # Новый стандарт:
    #
    # modules/name/files/check.sh
    #

    script="${module_dir}/files/check.sh"



    if [[ -x "${script}" ]]; then

        printf "%s\n" "${script}"

        return 0

    fi



    #
    # Совместимость со старой схемой
    #

    script="${module_dir}/files/check_${module}.sh"



    if [[ -x "${script}" ]]; then

        printf "%s\n" "${script}"

        return 0

    fi



    return 1
}



#
# Запуск проверки модуля
#

module_api_run()
{
    local module="${1:-}"
    local mode="${2:-status}"



    local script



    if ! script="$(module_api_get_check_script "${module}")"; then


        ui_error \
            "Модуль ${module}: отсутствует check-скрипт"


        return "${MODULE_STATUS_ERROR}"

    fi



    "${script}" "${mode}"

}



#
# Получить статус модуля
#

module_api_status()
{
    module_api_run "$1" "status"
}



#
# Получить отчет модуля
#

module_api_report()
{
    module_api_run "$1" "report"
}



#
# Машинная проверка
#

module_api_check()
{
    module_api_run "$1" "check"
}



#
# Полный отчет всех модулей
#

module_api_report_all()
{
    local module


    while read -r module
    do

        [[ -z "${module}" ]] && continue



        echo

        ui_separator

        ui_section \
            "Модуль: ${module}"



        if ! module_api_report "${module}"; then


            ui_error \
                "Модуль ${module} завершил отчет с ошибкой"


        fi


    done < <(
        module_api_list_installed
    )

}



#
# Проверка всех модулей
#

module_api_check_all()
{
    local module

    local failed=0



    while read -r module
    do

        [[ -z "${module}" ]] && continue



        if ! module_api_check "${module}"; then

            failed=$((failed+1))

        fi


    done < <(
        module_api_list_installed
    )



    return "${failed}"
}
