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
# Состояние APT в рамках текущего запуска
#

APT_UPDATED="${APT_UPDATED:-false}"



#
# Выполнение apt-get в неинтерактивном режиме
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
# Выполняется один раз за сессию
#

update_package_cache()
{
    if [[ "${APT_UPDATED}" == "true" ]]; then
        return 0
    fi


    log_info "PACKAGES" "Обновление индекса пакетов APT..."


    if run_apt update -qq; then

        APT_UPDATED="true"

        log_success "PACKAGES" "Индекс пакетов APT успешно обновлен."

    else

        log_error "PACKAGES" "Не удалось обновить индекс пакетов APT."

        return 1

    fi
}



#
# Проверка установленного пакета
#

package_installed()
{
    local package="${1:-}"


    [[ -n "${package}" ]] || {
        log_error "PACKAGES" "Имя пакета не указано."
        return 1
    }


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


    [[ -n "${package}" ]] || {

        log_error "PACKAGES" "Имя пакета не указано."

        return 1
    }



    if package_installed "${package}"; then

        log_info "PACKAGES" "Пакет уже установлен: ${package}"

        return 0

    fi



    update_package_cache



    log_info "PACKAGES" "Установка пакета: ${package}"



    if run_apt install "${package}"; then

        log_success "PACKAGES" "Пакет успешно установлен: ${package}"

    else

        log_error "PACKAGES" "Ошибка установки пакета: ${package}"

        return 1

    fi
}
