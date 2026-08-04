#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# CLI Команда: Самодиагностика системы LSM
#
# Назначение:
#   Проверка целостности установки LSM:
#
#   - права доступа;
#   - каталоги;
#   - systemd службы;
#   - systemd таймеры;
#   - установленные модули;
#   - доступность Docker;
#   - ошибки конфигурации.
#
# Путь:
#   commands/doctor.sh
# ==============================================================================


set -Eeuo pipefail



#
# Определение корня LSM
#

if [[ -z "${LSM_ROOT:-}" ]]; then

    LSM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fi


export LSM_ROOT



#
# Загрузка библиотек
#

for library in \
    "lib/core/common.sh" \
    "lib/core/logging.sh" \
    "lib/core/ui.sh" \
    "lib/installer/module_loader.sh" \
    "lib/installer/registry.sh" \
    "lib/installer/modules.sh" \
    "lib/installer/module_validator.sh"
do

    if [[ -f "${LSM_ROOT}/${library}" ]]; then

        # shellcheck source=/dev/null
        source "${LSM_ROOT}/${library}"

    fi

done



readonly DOCTOR_COMPONENT="DOCTOR"



#
# Проверка каталога
#

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


        return 1


    fi

}



#
# Проверка root
#

doctor_check_root()
{

    if [[ "${EUID}" -eq 0 ]]; then


        log_success \
            "${DOCTOR_COMPONENT}" \
            "Запущено с правами root"


    else


        log_error \
            "${DOCTOR_COMPONENT}" \
            "Необходимо выполнить от root"


        return 1


    fi

}



#
# Проверка systemd
#

doctor_check_systemd()
{


    if ! command -v systemctl >/dev/null 2>&1; then


        log_warn \
            "${DOCTOR_COMPONENT}" \
            "Systemd отсутствует"


        return 0


    fi



    log_info \
        "${DOCTOR_COMPONENT}" \
        "Проверка systemd служб"



    systemctl list-unit-files \
        "lsm-*.service" \
        --no-pager \
        || true



    echo



    log_info \
        "${DOCTOR_COMPONENT}" \
        "Проверка systemd timers"



    systemctl list-timers \
        "lsm-*.timer" \
        --all \
        --no-pager \
        || true

}



#
# Проверка модулей
#

doctor_check_modules()
{

    log_info \
        "${DOCTOR_COMPONENT}" \
        "Проверка модулей LSM"



    if ! declare -f modules_installed_list >/dev/null 2>&1; then


        log_warn \
            "${DOCTOR_COMPONENT}" \
            "API модулей недоступен"


        return 0


    fi



    local module



    while read -r module
    do


        [[ -z "${module}" ]] && continue



        if module_validate_all "${module}"; then


            log_success \
                "${DOCTOR_COMPONENT}" \
                "Модуль исправен: ${module}"


        else


            log_error \
                "${DOCTOR_COMPONENT}" \
                "Ошибка модуля: ${module}"


        fi



    done < <(
        modules_installed_list
    )

}



#
# Проверка Docker
#

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



    if systemctl is-active --quiet docker; then


        log_success \
            "${DOCTOR_COMPONENT}" \
            "docker.service активна"


    else


        log_warn \
            "${DOCTOR_COMPONENT}" \
            "docker.service не запущена"


    fi



}



#
# Основная диагностика
#

run_doctor()
{

    ui_section \
        "Диагностика Lite Server Monitor"



    echo



    echo "[1/7] Проверка прав"

    doctor_check_root || true



    echo
    echo "[2/7] Проверка каталогов"



    doctor_check_directory "/etc/lsm" || true
    doctor_check_directory "/opt/lsm" || true
    doctor_check_directory "/var/lib/lsm" || true
    doctor_check_directory "/var/log/lsm" || true



    echo
    echo "[3/7] Systemd"



    doctor_check_systemd



    echo
    echo "[4/7] Registry модулей"



    if declare -f registry_load_default >/dev/null 2>&1; then


        registry_load_default


        log_success \
            "${DOCTOR_COMPONENT}" \
            "Registry модулей загружен"


    fi



    echo
    echo "[5/7] Проверка модулей"



    doctor_check_modules



    echo
    echo "[6/7] Docker"



    doctor_check_docker



    echo
    echo "[7/7] Завершение"



    log_success \
        "${DOCTOR_COMPONENT}" \
        "Диагностика завершена"

}



run_doctor
