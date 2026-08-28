#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# CLI Команда: Самодиагностика системы
#
# Путь:
#   commands/doctor.sh
#
# Назначение:
#
#   Проверка корректности установленной системы LSM.
#
# Проверяет:
#
#   - права доступа;
#   - каталоги LSM;
#   - systemd;
#   - установленные модули;
#   - Docker;
#   - состояние компонентов.
#
# ==============================================================================


set -Eeuo pipefail



#
# Определение корня LSM
#

LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

export LSM_ROOT



#
# Загрузка библиотек
#

for library in \
    "lib/core/common.sh" \
    "lib/core/logging.sh" \
    "lib/core/ui.sh" \
    "lib/core/module_api.sh"
do

    if [[ -f "${LSM_ROOT}/${library}" ]]; then

        # shellcheck source=/dev/null
        source "${LSM_ROOT}/${library}"

    fi

done



readonly DOCTOR_COMPONENT="DOCTOR"



#
# Счетчики результата
#

DOCTOR_ERRORS=0
DOCTOR_WARNINGS=0



#
# Регистрация ошибки
#

doctor_error()
{

    DOCTOR_ERRORS=$((DOCTOR_ERRORS+1))

}



#
# Регистрация предупреждения
#

doctor_warn()
{

    DOCTOR_WARNINGS=$((DOCTOR_WARNINGS+1))

}



# ==============================================================================
# Проверка каталогов
# ==============================================================================

doctor_check_directory()
{

    local directory="$1"



    if [[ -d "${directory}" ]]; then


        log_success \
            "${DOCTOR_COMPONENT}" \
            "Каталог существует: ${directory}"


    else


        log_error \
            "${DOCTOR_COMPONENT}" \
            "Каталог отсутствует: ${directory}"


        doctor_error


    fi

}



# ==============================================================================
# Проверка root
# ==============================================================================

doctor_check_root()
{


    if [[ "${EUID}" -eq 0 ]]; then


        log_success \
            "${DOCTOR_COMPONENT}" \
            "Запуск выполнен с правами root"


    else


        log_error \
            "${DOCTOR_COMPONENT}" \
            "Требуются права root"


        doctor_error


    fi

}



# ==============================================================================
# Проверка systemd
# ==============================================================================

doctor_check_systemd()
{


    if ! command -v systemctl >/dev/null 2>&1; then

        log_warn \
            "${DOCTOR_COMPONENT}" \
            "Systemd отсутствует"

        doctor_warn

        return 0

    fi



    #
    # Компактная сводка вместо двух сырых таблиц systemctl.
    #
    # Подробные таблицы остаются доступны через:
    #
    #   systemctl list-unit-files 'lsm-*'
    #   systemctl list-timers 'lsm-*'
    #

    local unit_files
    local timers_total
    local timers_dead
    local dead_name

    unit_files="$(systemctl list-unit-files 'lsm-*.service' --no-legend 2>/dev/null | wc -l || echo 0)"

    timers_total="$(systemctl list-timers 'lsm-*.timer' --no-legend 2>/dev/null | wc -l || echo 0)"

    timers_dead="$(systemctl list-timers 'lsm-*.timer' --no-legend 2>/dev/null | awk '$1 == "-" { for (i = 1; i <= NF; i++) if ($i ~ /^lsm-.*\.timer$/) { print $i; break } }' || true)"


    log_info \
        "${DOCTOR_COMPONENT}" \
        "Systemd: юнитов служб ${unit_files}, таймеров ${timers_total}."


    if [[ -n "${timers_dead}" ]]; then

        for dead_name in ${timers_dead}; do

            log_warn \
                "${DOCTOR_COMPONENT}" \
                "Таймер без расписания (нет NEXT): ${dead_name}"

        done

        doctor_warn

    else

        log_success \
            "${DOCTOR_COMPONENT}" \
            "Все таймеры имеют расписание запусков."

    fi

}



# ==============================================================================
# Проверка модулей
# ==============================================================================

doctor_check_modules()
{


    log_info \
        "${DOCTOR_COMPONENT}" \
        "Проверка установленных модулей"



    if ! declare -f module_api_list_installed >/dev/null 2>&1; then


        log_warn \
            "${DOCTOR_COMPONENT}" \
            "Module API недоступен"


        doctor_warn


        return 0


    fi



    local module



    while read -r module
    do


        [[ -z "${module}" ]] && continue



        #
        # Системные модули (например core) проверяются
        # по собственному контракту и не требуют check-скрипта.
        #

        if declare -f module_api_is_system >/dev/null 2>&1 \
            && module_api_is_system "${module}"
        then

            local system_module_dir



            if module_api_exists "${module}" \
                && system_module_dir="$(module_api_path "${module}")" \
                && [[ -f "${system_module_dir}/manifest.conf" ]]
            then

                log_success \
                    "${DOCTOR_COMPONENT}" \
                    "Системный модуль установлен: ${module}"


            else

                log_error \
                    "${DOCTOR_COMPONENT}" \
                    "Системный модуль поврежден: ${module}"


                doctor_error


            fi



            continue


        fi



        if module_api_check "${module}"; then


            log_success \
                "${DOCTOR_COMPONENT}" \
                "Модуль исправен: ${module}"


        else


            log_error \
                "${DOCTOR_COMPONENT}" \
                "Ошибка проверки модуля: ${module}"


            doctor_error


        fi



    done < <(
        module_api_list_installed
    )


}



# ==============================================================================
# Проверка Docker
# ==============================================================================

doctor_check_docker()
{


    log_info \
        "${DOCTOR_COMPONENT}" \
        "Проверка Docker"



    if ! command -v docker >/dev/null 2>&1; then


        log_info \
            "${DOCTOR_COMPONENT}" \
            "Docker не установлен"


        return 0


    fi



    log_success \
        "${DOCTOR_COMPONENT}" \
        "Docker установлен"



    if systemctl is-active --quiet docker 2>/dev/null; then


        log_success \
            "${DOCTOR_COMPONENT}" \
            "docker.service активна"


    else


        log_warn \
            "${DOCTOR_COMPONENT}" \
            "docker.service не активна"


        doctor_warn


    fi



    if docker info >/dev/null 2>&1; then


        log_success \
            "${DOCTOR_COMPONENT}" \
            "Docker daemon доступен"


    else

        #
        # Docker является опциональным компонентом.
        # Если модуль docker не установлен,
        # недоступность daemon не считается ошибкой LSM.
        #

        local docker_module_installed=0



        if declare -f module_api_list_installed >/dev/null 2>&1 \
            && module_api_list_installed | grep -qx "docker"
        then

            docker_module_installed=1

        fi



        if (( docker_module_installed )); then


            log_error \
                "${DOCTOR_COMPONENT}" \
                "Docker daemon недоступен"


            doctor_error


        else


            log_info \
                "${DOCTOR_COMPONENT}" \
                "Docker daemon недоступен (модуль docker не установлен)"


        fi


    fi


}



# ==============================================================================
# Основной запуск диагностики
# ==============================================================================

run_doctor()
{

    #
    # Очистка только в интерактивном терминале:
    # при пайпах и перенаправлениях управляющие
    # символы в вывод не попадают.
    #

    if [[ -t 1 ]] && command -v clear >/dev/null 2>&1; then

        clear

    fi


    ui_banner


    ui_section \
        "Диагностика Lite Server Monitor"



    echo



    echo "[1/5] Проверка прав"

    doctor_check_root



    echo
    echo "[2/5] Проверка каталогов"



    doctor_check_directory "/etc/lsm"
    doctor_check_directory "/opt/lsm"
    doctor_check_directory "/var/lib/lsm"
    doctor_check_directory "/var/log/lsm"



    echo
    echo "[3/5] Systemd"



    doctor_check_systemd



    echo
    echo "[4/5] Модули"



    doctor_check_modules



    echo
    echo "[5/5] Docker"



    doctor_check_docker



    echo



    ui_section \
        "Итог диагностики"



    echo "Ошибок:        ${DOCTOR_ERRORS}"

    echo "Предупреждений: ${DOCTOR_WARNINGS}"



    if (( DOCTOR_ERRORS > 0 )); then


        log_error \
            "${DOCTOR_COMPONENT}" \
            "Диагностика завершена с ошибками."


        return 1


    fi



    log_success \
        "${DOCTOR_COMPONENT}" \
        "Система LSM работает корректно."



    return 0

}



run_doctor
