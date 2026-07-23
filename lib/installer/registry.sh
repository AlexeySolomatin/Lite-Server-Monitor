#!/usr/bin/env bash
#
# ==============================================================================
# Lite Server Monitor (LSM)
# Реестр компонентов установки
# Путь: lib/installer/registry.sh
# ==============================================================================


[[ -n "${LSM_INSTALL_REGISTRY_LOADED:-}" ]] && return
readonly LSM_INSTALL_REGISTRY_LOADED=1


declare -A LSM_COMPONENTS


#
# Добавление компонента
#
registry_add() {

    local name="$1"
    local description="$2"
    local default="$3"

    LSM_COMPONENTS["${name}"]="${description}|${default}"

}


#
# Получение всех компонентов
#
registry_list() {

    printf "%s\n" "${!LSM_COMPONENTS[@]}"

}


#
# Проверка существования
#
registry_exists() {

    local name="$1"

    [[ -n "${LSM_COMPONENTS[$name]:-}" ]]

}


#
# Получить описание
#
registry_description() {

    local name="$1"

    echo "${LSM_COMPONENTS[$name]%%|*}"

}


#
# Получить значение default
#
registry_default() {

    local name="$1"

    echo "${LSM_COMPONENTS[$name]##*|}"

}


#
# Стандартный набор компонентов
#
registry_load_default() {


    registry_add \
        "system" \
        "Мониторинг состояния системы" \
        "yes"


    registry_add \
        "disk" \
        "Контроль дискового пространства" \
        "yes"


    registry_add \
        "smart" \
        "SMART контроль накопителей" \
        "yes"


    registry_add \
        "temperature" \
        "Контроль температуры оборудования" \
        "yes"


    registry_add \
        "raid" \
        "Контроль RAID массива" \
        "yes"


    registry_add \
        "ups" \
        "Мониторинг UPS" \
        "no"


    registry_add \
        "login" \
        "Контроль входов пользователей" \
        "yes"


    registry_add \
        "fail2ban" \
        "Контроль защиты Fail2Ban" \
        "yes"


    registry_add \
        "core" \
        "Служебные функции LSM" \
        "yes"

}
