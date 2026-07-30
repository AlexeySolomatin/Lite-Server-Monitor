#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Шаг 02: Установка зависимостей и системных пакетов
# Путь: installer/steps/02_packages.sh
# ==============================================================================

set -Eeuo pipefail



readonly PACKAGES_COMPONENT="PACKAGES_STEP"



step_packages()
{

    print_section "Package Installation"



    log_info "${PACKAGES_COMPONENT}" \
        "Установка необходимых системных пакетов."



    #
    # Обновление индекса APT
    #

    if ! update_package_cache; then


        log_warn "${PACKAGES_COMPONENT}" \
            "Стандартное обновление APT завершилось ошибкой."


        log_info "${PACKAGES_COMPONENT}" \
            "Очистка списка пакетов и повторная попытка."


        rm -rf /var/lib/apt/lists/*



        if ! update_package_cache; then


            log_error "${PACKAGES_COMPONENT}" \
                "Не удалось обновить индекс APT."


            return 1


        fi

    fi



    #
    # Обязательные пакеты LSM
    #

    local pkgs=(

        curl
        wget
        jq
        bc

        msmtp

        smartmontools
        mdadm

        lm-sensors

        fail2ban

        dialog

    )



    #
    # Установка пакетов
    #

    for pkg in "${pkgs[@]}"; do


        if install_package "${pkg}"; then


            continue


        else


            log_error "${PACKAGES_COMPONENT}" \
                "Ошибка установки пакета: ${pkg}"


            return 1


        fi


    done



    log_success "${PACKAGES_COMPONENT}" \
        "Все необходимые пакеты успешно установлены."



    return 0

}



#
# Автономный запуск шага
#

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then


    LSM_ROOT="${LSM_ROOT:-/opt/lsm}"

    export LSM_ROOT



    source "${LSM_ROOT}/lib/core/common.sh"
    source "${LSM_ROOT}/lib/core/logging.sh"
    source "${LSM_ROOT}/lib/core/ui.sh"
    source "${LSM_ROOT}/lib/installer/packages.sh"



    step_packages


fi
