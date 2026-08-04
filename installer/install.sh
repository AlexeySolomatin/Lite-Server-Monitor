#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Главный скрипт установки
#
# Назначение:
#   Запускает установку LSM:
#
#   - проверка окружения;
#   - загрузка библиотек;
#   - запуск мастера установки;
#   - выполнение этапов установки;
#   - создание CLI команды lsm.
# ==============================================================================


set -Eeuo pipefail



#
# Пути проекта
#

INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LSM_ROOT="$(cd "${INSTALLER_DIR}/.." && pwd)"

export LSM_ROOT
export INSTALLER_DIR



#
# Подключение библиотек
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
# Компонент установки
#

readonly INSTALL_COMPONENT="INSTALLER"



#
# Версия проекта
#

if [[ -f "${LSM_ROOT}/VERSION" ]]; then

    PROJECT_VERSION="$(tr -d '\r\n' < "${LSM_ROOT}/VERSION")"

else

    PROJECT_VERSION="${PROJECT_VERSION:-0.1.0}"

fi

export PROJECT_VERSION



#
# Обработка критических ошибок
#

trap_install_error()
{

    local exit_code=$?
    local line_no=$1


    echo


    log_error "${INSTALL_COMPONENT}" \
        "Критическая ошибка установки. Строка: ${line_no}, код: ${exit_code}"


    log_error "${INSTALL_COMPONENT}" \
        "Установка LSM остановлена."


    exit "${exit_code}"

}


trap 'trap_install_error $LINENO' ERR



#
# Проверка прав администратора
#

if declare -f check_root >/dev/null 2>&1; then


    check_root


else


    if [[ "${EUID}" -ne 0 ]]; then


        echo "Ошибка: установка требует права root."

        exit 1


    fi


fi



#
# Определение режима запуска
#

NON_INTERACTIVE=false



if [[ "${1:-}" == "--quiet" ]] || \
   [[ "${1:-}" == "--non-interactive" ]] || \
   [[ "${1:-}" == "-y" ]]; then


    NON_INTERACTIVE=true


fi



#
# Загрузка реестра модулей
#

registry_load_default



#
# Интерактивная установка
#

if [[ "${NON_INTERACTIVE}" == "false" ]]; then



    if [[ -f "${INSTALLER_DIR}/wizard.sh" ]]; then


        source "${INSTALLER_DIR}/wizard.sh"


        run_install_wizard


    else


        log_error "${INSTALL_COMPONENT}" \
            "Не найден мастер установки wizard.sh"


        exit 1


    fi



#
# Автоматическая установка
#

else


    log_info "${INSTALL_COMPONENT}" \
        "Запуск автоматической установки."



    #
    # Стандартная установка без вопросов
    #

    INSTALL_MODE="standard"

    NOTIFICATION_METHOD="none"



    INSTALL_UPS=true
    UPS_PROFILE="default"



    DAILY_REPORT_ENABLED=true
    DAILY_REPORT_TIME="09:00"



    declare -a SELECTED_MODULES=()



    while read -r module; do


        [[ -z "${module}" ]] && continue


        SELECTED_MODULES+=("${module}")


    done < <(registry_list)



fi



#
# Старт установки
#

log_info "${INSTALL_COMPONENT}" \
    "Lite Server Monitor v${PROJECT_VERSION}"



log_info "${INSTALL_COMPONENT}" \
    "Зарегистрированные модули:"


registry_list



#
# Выполнение этапов установки
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
            "Отсутствует этап установки: ${step_path}"


        exit 1


    fi



    log_info "${INSTALL_COMPONENT}" \
        "Выполнение этапа: ${step_script}"



    source "${step_path}"



    step_name="$(
        echo "${step_script}" |
        sed -E 's/^[0-9]+_//; s/\.sh$//'
    )"



    step_function="step_${step_name}"



    if declare -f "${step_function}" >/dev/null 2>&1; then


        "${step_function}"


    else


        log_warn "${INSTALL_COMPONENT}" \
            "Функция этапа отсутствует: ${step_function}"


    fi



done



#
# Создание CLI команды
#

deploy_create_symlink \
    "${LSM_ROOT}/bin/lsm" \
    "/usr/local/bin/lsm"



#
# Завершение установки
#

echo


log_success "${INSTALL_COMPONENT}" \
    "Lite Server Monitor v${PROJECT_VERSION} установлен успешно."


log_info "${INSTALL_COMPONENT}" \
    "Команда управления: lsm help"
