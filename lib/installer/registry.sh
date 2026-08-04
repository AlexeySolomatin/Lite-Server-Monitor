#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# API реестра модулей установки v1.3
# Путь: lib/installer/registry.sh
#
# Назначение:
#   Управляет каталогом доступных модулей LSM.
#
# Возможности:
#   - поиск модулей в каталоге modules;
#   - загрузка описания модулей из manifest.conf;
#   - хранение информации о модулях;
#   - проверка существования модулей;
#   - получение списка модулей;
#   - проверка зависимостей;
#   - построение правильного порядка установки.
#
# Структура модуля:
#
#   modules/<module_name>/
#       manifest.conf
#       install.sh
#       uninstall.sh
#       files/
#       templates/
#
# Требования:
#   - Bash 4+
#   - module_loader.sh должен быть подключен до использования функций,
#     связанных с manifest.conf.
# ==============================================================================


set -Eeuo pipefail



#
# Защита от повторной загрузки библиотеки.
#

[[ -n "${LSM_INSTALL_REGISTRY_LOADED:-}" ]] && return 0

readonly LSM_INSTALL_REGISTRY_LOADED=1



#
# Компонент логирования.
#

readonly REGISTRY_COMPONENT="REGISTRY"



#
# Пути проекта.
#

LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

LSM_MODULES_DIR="${LSM_MODULES_DIR:-${LSM_ROOT}/modules}"



#
# Хранилище данных модулей.
#
# Используются ассоциативные массивы Bash.
#

declare -A LSM_MODULE_NAME

declare -A LSM_MODULE_DESCRIPTION

declare -A LSM_MODULE_VERSION

declare -A LSM_MODULE_CATEGORY

declare -A LSM_MODULE_DEPENDENCIES



#
# Таблица существующих модулей.
#

declare -A LSM_MODULE_EXISTS



#
# Состояние разрешения зависимостей.
#
# Используется для:
#   - предотвращения повторной обработки;
#   - обнаружения циклических зависимостей.
#

declare -A LSM_RESOLVING

declare -A LSM_RESOLVED



#
# Список зарегистрированных модулей.
#

declare -a LSM_MODULES=()



#
# Очистка текущего реестра.
#
# Используется перед повторным сканированием модулей.
#

registry_clear()
{

    LSM_MODULE_NAME=()

    LSM_MODULE_DESCRIPTION=()

    LSM_MODULE_VERSION=()

    LSM_MODULE_CATEGORY=()

    LSM_MODULE_DEPENDENCIES=()


    LSM_MODULE_EXISTS=()


    LSM_RESOLVING=()

    LSM_RESOLVED=()


    LSM_MODULES=()

}



#
# Добавление модуля в реестр.
#
# Последовательность:
#
#   1. Проверка имени.
#   2. Проверка manifest.conf.
#   3. Загрузка manifest.
#   4. Сохранение информации.
#

registry_add()
{

    local module="${1:-}"



    [[ -n "${module}" ]] || return 1



    #
    # Если модуль уже зарегистрирован,
    # повторная загрузка не требуется.
    #

    if [[ -v LSM_MODULE_EXISTS[$module] ]]; then

        return 0

    fi



    if ! module_has_manifest "${module}"; then


        log_warn \
            "${REGISTRY_COMPONENT}" \
            "Manifest отсутствует: ${module}"


        return 1


    fi



    if ! module_load_manifest "${module}"; then


        log_error \
            "${REGISTRY_COMPONENT}" \
            "Ошибка загрузки manifest: ${module}"


        return 1


    fi



    LSM_MODULE_EXISTS["${module}"]=1


    LSM_MODULES+=("${module}")



    #
    # Сохранение параметров из manifest.conf.
    #

    LSM_MODULE_NAME["${module}"]="${MODULE_NAME:-${module}}"

    LSM_MODULE_DESCRIPTION["${module}"]="${MODULE_DESCRIPTION:-}"

    LSM_MODULE_VERSION["${module}"]="${MODULE_VERSION:-unknown}"

    LSM_MODULE_CATEGORY["${module}"]="${MODULE_CATEGORY:-unknown}"

    LSM_MODULE_DEPENDENCIES["${module}"]="${MODULE_DEPENDENCIES:-}"

}



#
# Сканирование каталога modules.
#
# Каждый найденный каталог считается потенциальным модулем.
#

registry_scan()
{

    registry_clear



    [[ -d "${LSM_MODULES_DIR}" ]] || return 0



    while read -r module
    do


        [[ -z "${module}" ]] && continue


        registry_add "${module}" || true


    done < <(

        find "${LSM_MODULES_DIR}" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            -printf "%f\n" \
            2>/dev/null \
            | sort

    )



    log_info \
        "${REGISTRY_COMPONENT}" \
        "Загружено модулей: ${#LSM_MODULES[@]}"

}



#
# Загрузка стандартного реестра.
#

registry_load_default()
{

    registry_scan

}



#
# Проверка существования модуля.
#

registry_exists()
{

    local module="${1:-}"


    [[ -v LSM_MODULE_EXISTS[$module] ]]

}



#
# Вывод списка зарегистрированных модулей.
#

registry_list()
{

    printf "%s\n" "${LSM_MODULES[@]}"

}



#
# Получение списка зависимостей модуля.
#

registry_dependencies()
{

    local module="${1:-}"


    echo "${LSM_MODULE_DEPENDENCIES[$module]:-}"

}



#
# Вывод информации о модуле.
#

registry_info()
{

    local module="${1:-}"



    if ! registry_exists "${module}"; then

        return 1

    fi



cat <<EOF

Модуль:
${module}

Название:
${LSM_MODULE_NAME[$module]}

Описание:
${LSM_MODULE_DESCRIPTION[$module]}

Версия:
${LSM_MODULE_VERSION[$module]}

Категория:
${LSM_MODULE_CATEGORY[$module]}

Зависимости:
${LSM_MODULE_DEPENDENCIES[$module]:-нет}

EOF

}



#
# Проверка зависимостей модуля.
#

registry_check_dependencies()
{

    local module="${1:-}"



    if ! registry_exists "${module}"; then


        log_error \
            "${REGISTRY_COMPONENT}" \
            "Модуль отсутствует: ${module}"


        return 1


    fi



    local deps

    deps="$(registry_dependencies "${module}")"



    [[ -z "${deps// /}" ]] && return 0



    local dep



    for dep in ${deps}
    do


        if ! registry_exists "${dep}"; then


            log_error \
                "${REGISTRY_COMPONENT}" \
                "Модуль ${module}: отсутствует зависимость ${dep}"


            return 1


        fi


    done



    return 0

}



#
# Формирование порядка установки.
#
# В результате зависимости устанавливаются
# раньше зависимого модуля.
#

registry_resolve_order()
{

    local requested=("$@")


    local result=()



    LSM_RESOLVING=()

    LSM_RESOLVED=()



    local module



    for module in "${requested[@]}"
    do


        registry_resolve_module \
            "${module}" \
            result || return 1


    done



    printf "%s\n" "${result[@]}"

}



#
# Рекурсивное разрешение зависимостей.
#
# Алгоритм:
#
#   1. Проверка существования модуля.
#   2. Проверка, был ли модуль обработан.
#   3. Проверка циклической зависимости.
#   4. Обработка зависимостей.
#   5. Добавление модуля в итоговый список.
#

registry_resolve_module()
{

    local module="$1"

    local array_name="$2"



    if ! registry_exists "${module}"; then


        log_error \
            "${REGISTRY_COMPONENT}" \
            "Модуль отсутствует: ${module}"


        return 1


    fi



    if [[ "${LSM_RESOLVED[$module]:-}" == "true" ]]; then

        return 0

    fi



    if [[ "${LSM_RESOLVING[$module]:-}" == "true" ]]; then


        log_error \
            "${REGISTRY_COMPONENT}" \
            "Обнаружен цикл зависимостей: ${module}"


        return 1


    fi



    LSM_RESOLVING["${module}"]="true"



    local deps

    deps="$(registry_dependencies "${module}")"



    local dep



    if [[ -n "${deps// /}" ]]; then


        for dep in ${deps}
        do


            if ! registry_resolve_module \
                "${dep}" \
                "${array_name}"
            then


                LSM_RESOLVING["${module}"]=""


                return 1


            fi


        done


    fi



    LSM_RESOLVING["${module}"]=""

    LSM_RESOLVED["${module}"]="true"



    #
    # Добавление модуля в переданный массив.
    #
    # Используется имя массива,
    # так как Bash не передает массивы по ссылке.
    #

    eval "${array_name}+=(\"\${module}\")"



    return 0

}
