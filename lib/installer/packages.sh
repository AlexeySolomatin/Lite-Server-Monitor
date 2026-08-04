#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Библиотека управления пакетами APT
# Путь: lib/installer/packages.sh
#
# Назначение:
#   Предоставляет единый интерфейс для работы с пакетным менеджером APT.
#
# Возможности:
#   - проверка наличия необходимых прав;
#   - проверка доступности apt-get;
#   - безопасная проверка имени пакета;
#   - однократное обновление индекса пакетов;
#   - проверка установленного пакета;
#   - установка пакетов с сохранением текущих конфигураций.
#
# Использование:
#   install_package "package-name"
#
# Требования:
#   - Bash 4+
#   - Debian/Ubuntu-подобная система с APT
#   - запуск операций установки от root
# ==============================================================================


set -Eeuo pipefail



#
# Защита от повторной загрузки библиотеки.
#
# Позволяет безопасно подключать файл через source
# из нескольких частей установщика.
#

[[ -n "${LSM_PACKAGES_LOADED:-}" ]] && return 0

readonly LSM_PACKAGES_LOADED=1



#
# Компонент логирования.
#
# Используется во всех сообщениях библиотеки.
#

readonly PACKAGES_COMPONENT="PACKAGES"



#
# Состояние обновления индекса APT.
#
# В рамках одного запуска установщика:
#   false - индекс еще не обновлялся;
#   true  - apt update уже выполнен.
#
# Это предотвращает повторное выполнение apt update
# при установке нескольких пакетов.
#

APT_UPDATED="${APT_UPDATED:-false}"



#
# Проверка прав root.
#
# Установка и изменение пакетов требуют административных прав.
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
# Проверка наличия пакетного менеджера APT.
#
# Если apt-get отсутствует, текущая система
# не поддерживается данным модулем.
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
# Проверка корректности имени пакета.
#
# Разрешены только стандартные символы,
# используемые в именах Debian-пакетов:
#
#   a-z
#   A-Z
#   0-9
#   +
#   .
#   _
#   -
#
# Это исключает передачу опасных аргументов в apt-get.
#

packages_validate_name()
{

    local package="${1:-}"



    [[ -n "${package}" ]] || return 1



    [[ "${package}" =~ ^[a-zA-Z0-9][a-zA-Z0-9+._-]*$ ]]

}



#
# Унифицированный запуск apt-get.
#
# Параметры:
#   $@ - аргументы apt-get
#
# Используется:
#   - автоматическое подтверждение установки;
#   - сохранение существующих конфигурационных файлов.
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
# Обновление списка доступных пакетов.
#
# Выполняется только один раз за текущий запуск установщика.
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
# Проверка, установлен ли пакет.
#
# Возвращает:
#   0 - пакет установлен;
#   1 - пакет отсутствует или ошибка проверки.
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
# Установка пакета.
#
# Алгоритм:
#
#   1. Проверка имени пакета.
#   2. Проверка root.
#   3. Проверка apt.
#   4. Проверка существующей установки.
#   5. Обновление индекса пакетов при необходимости.
#   6. Установка пакета.
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
