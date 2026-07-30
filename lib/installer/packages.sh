#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Библиотека управления пакетами APT
# Путь: lib/installer/packages.sh
# ==============================================================================

set -Eeuo pipefail


[[ -n "${LSM_PACKAGES_LOADED:-}" ]] && return 0
readonly LSM_PACKAGES_LOADED=1



#
# Компонент логирования
#

readonly PACKAGES_COMPONENT="PACKAGES"



#
# Состояние APT в рамках текущего запуска
#

APT_UPDATED="${APT_UPDATED:-false}"



#
# Проверка root
#

packages_check_root()
{
    if [[ "${EUID}" -ne 0 ]]; then

        log_error "${PACKAGES_COMPONENT}" \
            "Операции APT требуют права root."

        return 1

    fi
}



#
# Проверка наличия apt-get
#

packages_check_apt()
{
    if ! command -v apt-get >/dev/null 2>&1; then

        log_error "${PACKAGES_COMPONENT}" \
            "Команда apt-get не найдена."

        return 1

    fi
}



#
# Проверка имени пакета
#

packages_validate_name()
{
    local package="${1:-}"


    [[ -n "${package}" ]] || return 1


    [[ "${package}" =~ ^[a-zA-Z0-9][a-zA-Z0-9+._-]*$ ]]
}



#
# Выполнение apt-get
#

run_apt()
{
    DEBIAN_FRONTEND=noninteractive \
    apt-get -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" \
        "$@"
}



#
# Обновление индекса пакетов
#
# Выполняется один раз за запуск
#

update_package_cache()
{

    if [[ "${APT_UPDATED}" == "true" ]]; then
        return 0
    fi



    packages_check_root || return 1
    packages_check_apt || return 1



    log_info "${PACKAGES_COMPONENT}" \
        "Обновление индекса пакетов APT..."



    if run_apt update -qq; then


        APT_UPDATED="true"


        log_success "${PACKAGES_COMPONENT}" \
            "Индекс пакетов APT успешно обновлен."


    else


        log_error "${PACKAGES_COMPONENT}" \
            "Не удалось обновить индекс пакетов APT."


        return 1

    fi
}



#
# Проверка установленного пакета
#

package_installed()
{
    local package="${1:-}"


    if ! packages_validate_name "${package}"; then

        log_error "${PACKAGES_COMPONENT}" \
            "Некорректное имя пакета: ${package}"

        return 1

    fi



    {
        dpkg-query \
            -W \
            -f='${Status}' \
            "${package}" \
            2>/dev/null || true

    } | grep -q "install ok installed"
}



#
# Установка пакета
#

install_package()
{
    local package="${1:-}"



    if ! packages_validate_name "${package}"; then

        log_error "${PACKAGES_COMPONENT}" \
            "Некорректное имя пакета: ${package}"

        return 1

    fi



    packages_check_root || return 1
    packages_check_apt || return 1



    if package_installed "${package}"; then


        log_info "${PACKAGES_COMPONENT}" \
            "Пакет уже установлен: ${package}"


        return 0

    fi



    update_package_cache || return 1



    log_info "${PACKAGES_COMPONENT}" \
        "Установка пакета: ${package}"



    if run_apt install "${package}"; then


        log_success "${PACKAGES_COMPONENT}" \
            "Пакет успешно установлен: ${package}"


    else


        log_error "${PACKAGES_COMPONENT}" \
            "Ошибка установки пакета: ${package}"


        return 1

    fi
}
