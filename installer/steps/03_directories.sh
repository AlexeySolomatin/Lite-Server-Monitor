#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Step 03: Directory Structure and Codebase Deployment
# Path: installer/steps/03_directories.sh
# -----------------------------------------------------------------------------

set -Eeuo pipefail


readonly DIRECTORIES_COMPONENT="DIRECTORIES"



step_directories()
{

    print_section "Directory Structure"



    #
    # Целевой каталог установки (LSM_INSTALL_DIR имеет приоритет над дефолтным /opt/lsm)
    #
    local target_dir="${LSM_INSTALL_DIR:-/opt/lsm}"
    local src_dir

    src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

    local etc_dir="${LSM_ETC_DIR:-/etc/lsm}"
    local log_dir="${LSM_LOG_DIR:-/var/log/lsm}"



    log_info "${DIRECTORIES_COMPONENT}" \
        "Создание структуры Lite Server Monitor в ${target_dir}."



    #
    # Основные каталоги приложения
    #

    mkdir -p \
        "${target_dir}/bin" \
        "${target_dir}/commands" \
        "${target_dir}/installer" \
        "${target_dir}/lib" \
        "${target_dir}/modules" \
        "${target_dir}/templates"



    #
    # Системные каталоги
    #

    mkdir -p \
        "${etc_dir}/modules" \
        "${log_dir}"



    #
    # Развертывание исходного кода
    #

    if [[ "${src_dir}" != "${target_dir}" ]]; then


        log_info "${DIRECTORIES_COMPONENT}" \
            "Копирование файлов LSM из ${src_dir} в ${target_dir}"



        cp -rf \
            "${src_dir}/bin" \
            "${target_dir}/"



        cp -rf \
            "${src_dir}/commands" \
            "${target_dir}/"



        cp -rf \
            "${src_dir}/installer" \
            "${target_dir}/"



        cp -rf \
            "${src_dir}/lib" \
            "${target_dir}/"



        cp -rf \
            "${src_dir}/modules" \
            "${target_dir}/"



        if [[ -d "${src_dir}/templates" ]]; then

            cp -rf \
                "${src_dir}/templates" \
                "${target_dir}/"

        fi



        if [[ -f "${src_dir}/VERSION" ]]; then

            cp -f \
                "${src_dir}/VERSION" \
                "${target_dir}/VERSION"

        fi



        if [[ -f "${src_dir}/CHANGELOG.md" ]]; then

            cp -f \
                "${src_dir}/CHANGELOG.md" \
                "${target_dir}/CHANGELOG.md"

        fi


    else


        log_info "${DIRECTORIES_COMPONENT}" \
            "Исходный каталог совпадает с целевым. Копирование пропущено."


    fi



    #
    # Базовые права приложения
    #

    find "${target_dir}" -type d -exec chmod 755 {} +
    find "${target_dir}" -type f -exec chmod 644 {} +



    #
    # Исполняемые файлы
    #

    chmod +x \
        "${target_dir}/bin/lsm" \
        2>/dev/null || true



    find "${target_dir}/installer" \
        -type f \
        -name "*.sh" \
        -exec chmod +x {} + \
        2>/dev/null || true



    find "${target_dir}/commands" \
        -type f \
        -name "*.sh" \
        -exec chmod +x {} + \
        2>/dev/null || true



    find "${target_dir}/modules" \
        -type f \
        -name "*.sh" \
        -exec chmod +x {} + \
        2>/dev/null || true
   



    log_success "${DIRECTORIES_COMPONENT}" \
        "Структура LSM создана и обновлена: ${target_dir}"


    return 0

}



#
# Автономный запуск
#

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then


    LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

    export LSM_ROOT



    source "${LSM_ROOT}/lib/core/common.sh"
    source "${LSM_ROOT}/lib/core/logging.sh"
    source "${LSM_ROOT}/lib/core/ui.sh"



    step_directories


fi
