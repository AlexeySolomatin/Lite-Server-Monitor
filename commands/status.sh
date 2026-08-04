#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# CLI Command: Status
#
# Назначение:
#   Отображение текущего состояния установленной системы LSM.
#
# Показывает:
#   - версию LSM;
#   - информацию о сервере;
#   - состояние каталогов LSM;
#   - установленные модули;
#   - активные systemd timers.
#
# Путь:
#   commands/status.sh
# ==============================================================================


set -Eeuo pipefail



#
# Определение корневого каталога LSM
#

if [[ -z "${LSM_ROOT:-}" ]]; then

    LSM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fi


export LSM_ROOT



#
# Загрузка библиотек LSM
#

for library in \
    "lib/core/common.sh" \
    "lib/core/logging.sh" \
    "lib/core/ui.sh"
do

    if [[ -f "${LSM_ROOT}/${library}" ]]; then

        # shellcheck source=/dev/null
        source "${LSM_ROOT}/${library}"

    fi

done



#
# Компонент логирования
#

readonly STATUS_COMPONENT="STATUS"



#
# Получение версии LSM
#

get_lsm_version()
{

    if [[ -f "${LSM_ROOT}/VERSION" ]]; then

        tr -d '\r\n' < "${LSM_ROOT}/VERSION"

    else

        echo "unknown"

    fi

}



#
# Проверка установки LSM
#

check_installation()
{

    local result=0



    printf "Состояние установки:\n"



    if [[ -d "/etc/lsm" ]]; then

        printf "  ✓ Конфигурация: /etc/lsm\n"

    else

        printf "  ✗ Конфигурация отсутствует: /etc/lsm\n"

        result=1

    fi



    if [[ -d "/var/lib/lsm" ]]; then

        printf "  ✓ Данные: /var/lib/lsm\n"

    else

        printf "  ✗ Данные отсутствуют: /var/lib/lsm\n"

        result=1

    fi



    if [[ -d "/var/log/lsm" ]]; then

        printf "  ✓ Логи: /var/log/lsm\n"

    else

        printf "  ! Каталог логов отсутствует\n"

    fi



    return "${result}"

}



#
# Вывод установленных модулей
#

show_modules()
{

    local state_dir="/var/lib/lsm/modules"



    printf "Модули LSM:\n"



    if [[ ! -d "${state_dir}" ]]; then

        printf "  Нет данных о модулях\n"

        return 0

    fi



    local count=0



    while read -r file
    do

        [[ -z "${file}" ]] && continue


        local module

        module="$(basename "${file}" .installed)"


        local installed_date

        installed_date="$(cat "${file}")"



        printf "  ✓ %-15s (%s)\n" \
            "${module}" \
            "${installed_date}"



        count=$((count+1))


    done < <(
        find "${state_dir}" \
            -type f \
            -name "*.installed" \
            2>/dev/null \
            | sort
    )



    if (( count == 0 )); then

        printf "  Нет установленных модулей\n"

    else

        printf "Всего модулей: %s\n" "${count}"

    fi

}



#
# Вывод systemd timers
#

show_timers()
{

    printf "Systemd timers:\n"



    if ! command -v systemctl >/dev/null 2>&1; then

        printf "  Systemd недоступен\n"

        return 0

    fi



    local timers


    timers="$(
        systemctl list-timers \
            "lsm-*" \
            --no-pager \
            --no-legend \
            2>/dev/null \
            || true
    )"



    if [[ -z "${timers}" ]]; then

        printf "  Активные таймеры отсутствуют\n"

    else

        printf "%s\n" "${timers}"

    fi

}



#
# Основная функция
#

show_status()
{

    ui_section "Состояние Lite Server Monitor"



    printf "Версия LSM: %s\n\n" \
        "$(get_lsm_version)"



    printf "Информация о сервере:\n"


    printf "  ОС:          %s\n" \
        "$(uname -srm)"


    printf "  Имя узла:    %s\n" \
        "$(hostname)"


    printf "  Время работы: %s\n\n" \
        "$(uptime -p 2>/dev/null || uptime)"



    check_installation || true



    printf "\n"



    show_modules



    printf "\n"



    show_timers

}



#
# Запуск команды
#

show_status
