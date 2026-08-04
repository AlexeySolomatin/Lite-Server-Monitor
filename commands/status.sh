#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# CLI Command: Status
#
# Назначение:
#   Отображение текущего состояния LSM и системного окружения.
#
# Возможности:
#   - информация о системе;
#   - версия LSM;
#   - состояние установки;
#   - список установленных модулей;
#   - состояние systemd timers.
#
# Путь:
#   commands/status.sh
# ==============================================================================


set -Eeuo pipefail



#
# Определение корня проекта
#

if [[ -z "${LSM_ROOT:-}" ]]; then

    LSM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fi


export LSM_ROOT



#
# Загрузка базовых библиотек LSM
#

if [[ -f "${LSM_ROOT}/lib/core/common.sh" ]]; then

    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/core/common.sh"

fi



if [[ -f "${LSM_ROOT}/lib/core/logging.sh" ]]; then

    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/core/logging.sh"

fi



if [[ -f "${LSM_ROOT}/lib/core/ui.sh" ]]; then

    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/core/ui.sh"

fi



#
# Константы
#

readonly STATUS_COMPONENT="STATUS"



#
# Основная функция статуса
#

show_status()
{

    ui_section "LSM Monitor Status"



    #
    # Версия LSM
    #

    if [[ -f "${LSM_ROOT}/VERSION" ]]; then


        local version

        version="$(tr -d '\r\n' < "${LSM_ROOT}/VERSION")"


        printf "Версия LSM: %s\n" "${version}"


    else


        printf "Версия LSM: неизвестна\n"


    fi



    printf "\n"



    #
    # Информация о системе
    #

    printf "Система:\n"

    printf "  ОС:       %s\n" \
        "$(uname -srm)"



    printf "  Имя узла: %s\n" \
        "$(hostname)"



    printf "  Время работы: %s\n" \
        "$(uptime -p 2>/dev/null || uptime)"



    printf "\n"



    #
    # Проверка установки LSM
    #

    printf "Состояние установки:\n"


    if [[ -d "/etc/lsm" ]] || \
       [[ -d "/var/lib/lsm" ]]; then


        printf "  ✓ LSM установлен\n"


    else


        printf "  ✗ LSM не обнаружен\n"


    fi



    printf "\n"



    #
    # Установленные модули
    #

    printf "Модули LSM:\n"


    local state_dir="${LSM_DATA_DIR:-/var/lib/lsm}/modules"


    if [[ -d "${state_dir}" ]]; then


        local modules_found=false


        while read -r module_file
        do

            modules_found=true


            printf "  ✓ %s\n" \
                "$(basename "${module_file}" .installed)"


        done < <(
            find "${state_dir}" \
                -name "*.installed" \
                -type f \
                2>/dev/null \
                | sort
        )



        if [[ "${modules_found}" == "false" ]]; then

            printf "  Нет установленных модулей\n"

        fi


    else


        printf "  Каталог состояния отсутствует\n"


    fi



    printf "\n"



    #
    # Проверка systemd
    #

    printf "Systemd timers:\n"



    if command -v systemctl >/dev/null 2>&1; then



        local timers


        timers="$(
            systemctl list-timers \
                "lsm-*" \
                --no-pager \
                --no-legend \
                2>/dev/null \
                || true
        )"



        if [[ -n "${timers}" ]]; then


            printf "%s\n" "${timers}"


        else


            printf "  Активные таймеры LSM отсутствуют\n"


        fi



    else


        if declare -f log_warn >/dev/null 2>&1; then


            log_warn \
                "${STATUS_COMPONENT}" \
                "Systemd отсутствует в текущей системе."


        else


            printf "  Systemd отсутствует\n"


        fi


    fi

}



#
# Запуск
#

show_status
