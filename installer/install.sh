#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Master Installation Script
# -----------------------------------------------------------------------------

set -Eeuo pipefail



#
# Пути проекта
#

INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LSM_ROOT="$(cd "${INSTALLER_DIR}/.." && pwd)"

export LSM_ROOT
export INSTALLER_DIR



#
# Загрузка библиотек
#

source "${LSM_ROOT}/lib/core/logging.sh"
source "${LSM_ROOT}/lib/core/common.sh"
source "${LSM_ROOT}/lib/core/ui.sh"

source "${LSM_ROOT}/lib/installer/deploy.sh"
source "${LSM_ROOT}/lib/installer/packages.sh"

source "${LSM_ROOT}/lib/installer/module_loader.sh"
source "${LSM_ROOT}/lib/installer/registry.sh"
source "${LSM_ROOT}/lib/installer/modules.sh"
source "${LSM_ROOT}/lib/installer/module_validator.sh"



#
# Компонент
#

readonly INSTALL_COMPONENT="INSTALLER"



#
# Версия
#

if [[ -f "${LSM_ROOT}/VERSION" ]]; then

    PROJECT_VERSION="$(tr -d '\r\n' < "${LSM_ROOT}/VERSION")"

else

    PROJECT_VERSION="${PROJECT_VERSION:-0.1.0}"

fi

export PROJECT_VERSION



#
# Обработка ошибок
#

trap_install_error()
{
    local exit_code=$?
    local line_no=$1


    echo


    log_error "${INSTALL_COMPONENT}" \
        "Критическая ошибка установки. Строка: ${line_no}, код: ${exit_code}"

    log_error "${INSTALL_COMPONENT}" \
        "Установка Lite Server Monitor прервана."


    exit "${exit_code}"
}


trap 'trap_install_error $LINENO' ERR



#
# Проверка root
#

if declare -f check_root >/dev/null 2>&1; then

    check_root

else

    if [[ "${EUID}" -ne 0 ]]; then

        echo "ERROR: installer requires root privileges."
        exit 1

    fi

fi



#
# Режим установки
#

NON_INTERACTIVE=false


if [[ "${1:-}" == "--quiet" ||
      "${1:-}" == "--non-interactive" ||
      "${1:-}" == "-y" ]]; then

    NON_INTERACTIVE=true

fi



#
# Загрузка реестра модулей
#

registry_load_default



if [[ "${NON_INTERACTIVE}" == "false" ]]; then


    if [[ -f "${INSTALLER_DIR}/wizard.sh" ]]; then

        source "${INSTALLER_DIR}/wizard.sh"

        run_install_wizard

    fi



else


    log_info "${INSTALL_COMPONENT}" \
        "Запуск установки в автоматическом режиме."



    INSTALL_MODE="${INSTALL_MODE:-full}"
    NOTIFICATION_METHOD="${NOTIFICATION_METHOD:-none}"

    declare -a SELECTED_MODULES=()



    while read -r module; do


        if [[ "$(registry_default "${module}")" == "yes" ]]; then

            SELECTED_MODULES+=("${module}")

        fi


    done < <(registry_list)



fi



#
# Старт установки
#

log_info "${INSTALL_COMPONENT}" \
    "Запуск Lite Server Monitor v${PROJECT_VERSION}"



log_info "${INSTALL_COMPONENT}" \
    "Зарегистрированные модули:"


registry_list



#
# Шаги установки
#

STEPS=(
    "01_environment.sh"
    "02_packages.sh"
    "03_directories.sh"
    "04_configuration.sh"
    "05_modules.sh"
    "06_services.sh"
    "07_permissions.sh"
    "08_finish.sh"
)



for step_script in "${STEPS[@]}"; do


    step_path="${INSTALLER_DIR}/steps/${step_script}"


    if [[ ! -f "${step_path}" ]]; then


        log_error "${INSTALL_COMPONENT}" \
            "Отсутствует обязательный шаг: ${step_path}"


        exit 1


    fi



    log_info "${INSTALL_COMPONENT}" \
        "Выполнение шага: ${step_script}"



    source "${step_path}"



    step_func_name="$(
        echo "${step_script}" |
        sed -E 's/^[0-9]+_//; s/\.sh$//'
    )"


    step_func_name="step_${step_func_name}"



    if declare -f "${step_func_name}" >/dev/null 2>&1; then


        "${step_func_name}"


    else


        log_warn "${INSTALL_COMPONENT}" \
            "Функция шага отсутствует: ${step_func_name}"


    fi


done



#
# Создание CLI ссылки
#

deploy_create_symlink \
    "${LSM_ROOT}/bin/lsm" \
    "/usr/local/bin/lsm"



#
# Завершение
#

echo


log_success "${INSTALL_COMPONENT}" \
    "Lite Server Monitor v${PROJECT_VERSION} успешно установлен."


log_info "${INSTALL_COMPONENT}" \
    "Для справки выполните: lsm help"
