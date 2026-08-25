#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# API взаимодействия с модулями
#
# Путь:
#   lib/core/module_api.sh
#
# Назначение:
#   Единый интерфейс взаимодействия ядра LSM с модулями мониторинга.
#
# Используется:
#   - lib/core/report.sh
#   - commands/report.sh
#   - commands/doctor.sh
#   - commands/status.sh
#   - другие компоненты, которым требуется запуск проверки модуля
#
# Поддерживаемый интерфейс модулей:
#
#   check_<module>.sh status
#       Краткий статус модуля
#
#   check_<module>.sh report
#       Подробный отчет модуля
#
#   check_<module>.sh check
#       Машинная проверка состояния
#
# Структура модуля:
#
#   modules/<module>/
#       install.sh
#       uninstall.sh
#       manifest.conf
#       README.md
#       files/
#           check_<module>.sh
#
# Дополнительно поддерживается:
#
#   modules/<module>/files/check.sh
#
# ==============================================================================


set -Eeuo pipefail



#
# Защита от повторной загрузки библиотеки.
#

[[ -n "${LSM_MODULE_API_LOADED:-}" ]] && return 0

readonly LSM_MODULE_API_LOADED=1



# ==============================================================================
# Конфигурация
# ==============================================================================

#
# Компонент логирования.
#

readonly MODULE_API_COMPONENT="MODULE_API"



#
# Корень проекта.
#
# Используется существующий LSM_ROOT,
# если он уже был установлен вызывающим компонентом.
#

LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

export LSM_ROOT



#
# Каталог модулей.
#

LSM_MODULES_DIR="${LSM_MODULES_DIR:-${LSM_ROOT}/modules}"



#
# Каталог состояния LSM.
#

LSM_STATE_DIR="${LSM_STATE_DIR:-/var/lib/lsm}"



#
# Каталог state-файлов модулей.
#

LSM_MODULE_STATE_DIR="${LSM_MODULE_STATE_DIR:-${LSM_STATE_DIR}/modules}"



# ==============================================================================
# Внутренние функции
# ==============================================================================

#
# Проверка имени модуля.
#
# Имена модулей LSM должны состоять только из:
#
#   a-z
#   A-Z
#   0-9
#   _
#   -
#
# Это одновременно обеспечивает предсказуемость структуры
# и не позволяет передавать в API произвольные пути.
#

_module_api_valid_name()
{
    local module="${1:-}"



    [[ -n "${module}" ]] || return 1



    [[ "${module}" =~ ^[a-zA-Z0-9_-]+$ ]]
}



#
# Проверка допустимого режима запуска.
#

_module_api_valid_mode()
{
    local mode="${1:-}"



    case "${mode}" in

        status|report|check)
            return 0
            ;;

        *)
            return 1
            ;;

    esac
}



#
# Безопасное предупреждение.
#
# module_api.sh обычно загружается после logging.sh.
# Однако библиотека не должна падать только потому,
# что logging.sh еще не был загружен.
#

_module_api_log_warn()
{
    if declare -f log_warn >/dev/null 2>&1; then

        log_warn \
            "${MODULE_API_COMPONENT}" \
            "$*"

    fi
}



#
# Безопасное сообщение об ошибке.
#

_module_api_log_error()
{
    if declare -f log_error >/dev/null 2>&1; then

        log_error \
            "${MODULE_API_COMPONENT}" \
            "$*"

    fi
}



#
# Получение категории модуля из manifest.conf.
#
# Манифест намеренно НЕ source-ится,
# чтобы избежать побочных эффектов
# в вызывающем процессе.
#

_module_api_get_category()
{
    local module="${1:-}"



    _module_api_valid_name "${module}" || return 1



    local manifest="${LSM_MODULES_DIR}/${module}/manifest.conf"

    [[ -f "${manifest}" ]] || return 1



    local line

    local category=""



    while IFS= read -r line || [[ -n "${line}" ]]
    do

        line="${line%$'\r'}"



        case "${line}" in

            MODULE_CATEGORY=*)
                category="${line#MODULE_CATEGORY=}"
                ;;

        esac

    done < "${manifest}"



    #
    # Снятие необязательных кавычек значения.
    #

    case "${category}" in

        \"*\") category="${category:1:${#category}-2}" ;;
        \'*\') category="${category:1:${#category}-2}" ;;

    esac



    printf '%s\n' "${category}"

    return 0
}



#
# module_api_is_system MODULE
#
# Возвращает 0, если модуль является системным
# (MODULE_CATEGORY="system" в manifest.conf).
#
# Системные модули (например core) не являются
# мониторинговыми и не обязаны иметь check-скрипт.
#

module_api_is_system()
{
    local module="${1:-}"

    local category



    category="$(_module_api_get_category "${module}")" || return 1



    [[ "${category}" == "system" ]]
}



#
# Безопасное debug-сообщение.
#

_module_api_log_debug()
{
    if declare -f log_debug >/dev/null 2>&1; then

        log_debug \
            "${MODULE_API_COMPONENT}" \
            "$*"

    fi
}



# ==============================================================================
# Список установленных модулей
# ==============================================================================

#
# module_api_list_installed
#
# Возвращает имена установленных модулей.
#
# Основной механизм:
#
#   modules_installed_list
#
# если он уже предоставлен lib/installer/modules.sh.
#
# Fallback:
#
#   /var/lib/lsm/modules/*.installed
#
# Результат:
#
#   disk
#   docker
#   raid
#   smart
#   ...
#

module_api_list_installed()
{

    #
    # Предпочтительно используем существующий API installer/modules.sh.
    #

    if declare -f modules_installed_list >/dev/null 2>&1; then

        modules_installed_list

        return 0

    fi



    #
    # Fallback.
    #

    [[ -d "${LSM_MODULE_STATE_DIR}" ]] || return 0



    find "${LSM_MODULE_STATE_DIR}" \
        -maxdepth 1 \
        -type f \
        -name "*.installed" \
        -printf "%f\n" \
        2>/dev/null \
        | sed 's/\.installed$//' \
        | sort

}



# ==============================================================================
# Проверка существования модуля
# ==============================================================================

#
# module_api_exists MODULE
#
# Возвращает:
#
#   0 - модуль существует
#   1 - модуль отсутствует
#

module_api_exists()
{
    local module="${1:-}"



    _module_api_valid_name "${module}" || return 1



    [[ -d "${LSM_MODULES_DIR}/${module}" ]]
}



# ==============================================================================
# Получение каталога модуля
# ==============================================================================

#
# module_api_path MODULE
#
# Выводит абсолютный путь к каталогу модуля.
#

module_api_path()
{
    local module="${1:-}"



    if ! module_api_exists "${module}"; then

        return 1

    fi



    printf '%s\n' \
        "${LSM_MODULES_DIR}/${module}"

}



# ==============================================================================
# Получение check-скрипта модуля
# ==============================================================================

#
# module_api_get_check_script MODULE
#
# Стандартное расположение:
#
#   modules/<module>/files/check_<module>.sh
#
# Дополнительный поддерживаемый вариант:
#
#   modules/<module>/files/check.sh
#
# Скрипт должен быть исполняемым.
#

module_api_get_check_script()
{
    local module="${1:-}"



    local module_dir



    if ! module_dir="$(module_api_path "${module}")"; then

        return 1

    fi



    local check_script



    #
    # Стандартный вариант.
    #

    check_script="${module_dir}/files/check_${module}.sh"



    if [[ -x "${check_script}" ]]; then

        printf '%s\n' \
            "${check_script}"

        return 0

    fi



    #
    # Fallback для модулей,
    # использующих общее имя check.sh.
    #

    check_script="${module_dir}/files/check.sh"



    if [[ -x "${check_script}" ]]; then

        printf '%s\n' \
            "${check_script}"

        return 0

    fi



    return 1

}



# ==============================================================================
# Запуск одного модуля
# ==============================================================================

#
# module_api_run MODULE MODE
#
# MODULE:
#
#   имя установленного/доступного модуля
#
# MODE:
#
#   status
#   report
#   check
#
# Возвращает код завершения check-скрипта.
#

module_api_run()
{
    local module="${1:-}"
    local mode="${2:-status}"



    #
    # Проверяем имя модуля до формирования пути.
    #

    if ! _module_api_valid_name "${module}"; then

        _module_api_log_error \
            "Недопустимое имя модуля: ${module}"

        return 1

    fi



    #
    # Проверяем режим.
    #

    if ! _module_api_valid_mode "${mode}"; then

        _module_api_log_error \
            "Недопустимый режим модуля: ${mode}"

        return 1

    fi



    #
    # Получаем check-скрипт.
    #

    local script



    if ! script="$(module_api_get_check_script "${module}")"; then

        #
        # Системные модули (например core) не обязаны
        # иметь check-скрипт и не проверяются
        # как обычные мониторинговые модули.
        #

        if module_api_is_system "${module}"; then

            _module_api_log_debug \
                "Системный модуль без check-скрипта: ${module}"

            return 0

        fi

        _module_api_log_error \
            "Check-скрипт отсутствует: ${module}"

        return 1

    fi



    #
    # Debug не является частью пользовательского отчета.
    # Это исключительно диагностическое событие API.
    #

    _module_api_log_debug \
        "Запуск модуля: ${module}, режим: ${mode}"



    #
    # Запускаем check-скрипт.
    #
    # Код возврата намеренно передается вызывающему компоненту.
    #
    # Именно check-скрипт определяет:
    #
    #   0     состояние/операция успешны
    #   != 0  обнаружена проблема или произошла ошибка
    #

    "${script}" "${mode}"

}



# ==============================================================================
# Краткий статус
# ==============================================================================

#
# module_api_status MODULE
#

module_api_status()
{
    local module="${1:-}"



    module_api_run \
        "${module}" \
        "status"

}



# ==============================================================================
# Подробный отчет
# ==============================================================================

#
# module_api_report MODULE
#

module_api_report()
{
    local module="${1:-}"



    module_api_run \
        "${module}" \
        "report"

}



# ==============================================================================
# Машинная проверка
# ==============================================================================

#
# module_api_check MODULE
#
# Используется для определения,
# успешно ли прошла проверка модуля.
#

module_api_check()
{
    local module="${1:-}"



    module_api_run \
        "${module}" \
        "check"

}



# ==============================================================================
# Отчет по всем установленным модулям
# ==============================================================================

#
# module_api_report_all
#
# Запускает report для каждого установленного модуля.
#
# Важно:
#
#   Эта функция не занимается форматированием отдельных
#   результатов проверки.
#
#   Формат результата предоставляет сам check_<module>.sh.
#
#   module_api отвечает только за последовательный запуск модулей.
#

module_api_report_all()
{
    local module



    while IFS= read -r module
    do

        [[ -z "${module}" ]] && continue



        #
        # Системные модули не формируют отчетов.
        #

        if module_api_is_system "${module}"; then

            continue

        fi



        #
        # Заголовок модуля.
        #
        # Если ui_section доступен,
        # используем централизованный UI.
        #
        # Иначе используем простой текстовый fallback.
        #

        if declare -f ui_section >/dev/null 2>&1; then

            ui_section \
                "Модуль: ${module^^}"

        else

            printf '\n'
            printf '%s\n' \
                '=============================================================================='
            printf ' МОДУЛЬ: %s\n' \
                "${module^^}"
            printf '%s\n' \
                '=============================================================================='

        fi



        #
        # Ошибка одного модуля не должна
        # останавливать отчет остальных модулей.
        #

        if ! module_api_report "${module}"; then

            _module_api_log_error \
                "Ошибка отчета модуля: ${module}"

        fi



    done < <(
        module_api_list_installed
    )

}



# ==============================================================================
# Проверка всех установленных модулей
# ==============================================================================

#
# module_api_check_all
#
# Проверяет все установленные модули.
#
# Возвращает:
#
#   0 - все проверки успешны
#   >0 - количество модулей, завершившихся ошибкой
#
# Проверка всех модулей продолжается даже после обнаружения
# первой ошибки.
#

module_api_check_all()
{
    local module

    local failed=0



    while IFS= read -r module
    do

        [[ -z "${module}" ]] && continue



        #
        # Системные модули не проходят
        # мониторинговую check-проверку.
        #

        if module_api_is_system "${module}"; then

            continue

        fi



        if ! module_api_check "${module}"; then

            failed=$((failed + 1))

        fi



    done < <(
        module_api_list_installed
    )



    return "${failed}"

}
