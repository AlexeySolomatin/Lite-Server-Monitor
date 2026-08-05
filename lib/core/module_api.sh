#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Module API v1.0
#
# Назначение:
#   Единый интерфейс взаимодействия ядра LSM с модулями мониторинга.
#
# Используется:
#   - report.sh      генерация отчетов
#   - doctor.sh      диагностика системы
#   - status.sh      отображение состояния
#
# Поддерживаемый интерфейс модулей:
#
#   check_<module>.sh status
#       Краткий статус модуля
#
#   check_<module>.sh report
#       Подробный отчет
#
#   check_<module>.sh check
#       Машинная проверка состояния
#
# Путь:
#   lib/core/module_api.sh
# ==============================================================================


set -Eeuo pipefail


#
# Защита от повторной загрузки библиотеки
#

if [[ -n "${LSM_MODULE_API_LOADED:-}" ]]; then
    return 0
fi

readonly LSM_MODULE_API_LOADED=1



#
# Компонент логирования
#

readonly MODULE_API_COMPONENT="MODULE_API"



#
# Пути LSM
#

LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

LSM_MODULES_DIR="${LSM_MODULES_DIR:-${LSM_ROOT}/modules}"

LSM_STATE_DIR="${LSM_STATE_DIR:-/var/lib/lsm}"

LSM_MODULE_STATE_DIR="${LSM_MODULE_STATE_DIR:-${LSM_STATE_DIR}/modules}"



#
# Получение списка установленных модулей
#
# Использует существующий механизм state-файлов.
#

module_api_list_installed()
{

    if declare -f modules_installed_list >/dev/null 2>&1; then

        modules_installed_list

        return 0

    fi



    #
    # Fallback если modules.sh еще не загружен
    #

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
# Получение check-скрипта модуля
#
# Стандарт:
#
# modules/<module>/files/check_<module>.sh
#

module_api_get_check_script()
{
    local module="${1:-}"


    local module_dir


    module_dir="$(module_api_path "${module}")" \
        || return 1



    local check_script

    check_script="${module_dir}/files/check_${module}.sh"



    if [[ -x "${check_script}" ]]; then

        printf "%s\n" "${check_script}"

        return 0

    fi



    #
    # Поддержка альтернативного имени
    #

    check_script="${module_dir}/files/check.sh"


    if [[ -x "${check_script}" ]]; then

        printf "%s\n" "${check_script}"

        return 0

    fi



    return 1

}



#
# Запуск проверки модуля
#
# Аргументы:
#
#   $1 - имя модуля
#   $2 - режим
#
# Режимы:
#
#   status
#   report
#   check
#

module_api_run()
{
    local module="${1:-}"
    local mode="${2:-status}"



    local script


    if ! script="$(module_api_get_check_script "${module}")"; then

        log_warn \
            "${MODULE_API_COMPONENT}" \
            "Check-скрипт отсутствует: ${module}"

        return 1

    fi



    log_debug \
        "${MODULE_API_COMPONENT}" \
        "Запуск ${module}: ${mode}"



    "${script}" "${mode}"

}



#
# Краткий статус модуля
#

module_api_status()
{
    local module="${1:-}"


    module_api_run \
        "${module}" \
        "status"

}



#
# Подробный отчет модуля
#

module_api_report()
{
    local module="${1:-}"


    module_api_run \
        "${module}" \
        "report"

}



#
# Машинная проверка состояния
#

module_api_check()
{
    local module="${1:-}"


    module_api_run \
        "${module}" \
        "check"

}



#
# Полный отчет по всем установленным модулям
#

module_api_report_all()
{
    local module



    while read -r module
    do

        [[ -z "${module}" ]] && continue


        echo
        echo "=============================================================================="
        echo " МОДУЛЬ: ${module^^}"
        echo "=============================================================================="


        if ! module_api_report "${module}"; then

            echo "[ERROR] Модуль ${module} завершил отчет с ошибкой."

        fi


    done < <(
        module_api_list_installed
    )

}



#
# Полная проверка всех модулей
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
