#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Главный скрипт установки
#
# Путь:
#   installer/installer.sh
#
# Назначение:
#   Центральная точка запуска установки Lite Server Monitor.
#
# Выполняемые задачи:
#
#   1. Определение расположения проекта.
#   2. Загрузка основных библиотек LSM.
#   3. Проверка прав администратора.
#   4. Определение режима установки:
#
#          интерактивный:
#              запуск мастера установки wizard.sh
#
#          автоматический:
#              установка стандартной конфигурации
#
#   5. Загрузка реестра модулей.
#   6. Выполнение последовательных этапов установки.
#   7. Создание системной команды:
#
#          /usr/local/bin/lsm
#
# Важно:
#
#   Данный файл управляет только последовательностью установки.
#   Логика отдельных компонентов находится в:
#
#       lib/
#       installer/steps/
#       installer/screens/
#
# ==============================================================================


set -Eeuo pipefail



#
# Определение путей проекта.
#
# INSTALLER_DIR:
#   каталог текущего установщика.
#
# LSM_ROOT:
#   корень проекта LSM.
#

INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LSM_ROOT="$(cd "${INSTALLER_DIR}/.." && pwd)"



export LSM_ROOT

export INSTALLER_DIR



#
# Подключение базовых библиотек.
#
# Порядок загрузки важен:
#
#   logging.sh
#       предоставляет функции log_*
#
#   common.sh
#       предоставляет системные проверки
#
#   ui.sh
#       интерфейс мастера
#
#   installer/*
#       функции установки
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
# Идентификатор компонента.
#
# Используется в журнале установки.
#

readonly INSTALL_COMPONENT="INSTALLER"



#
# Версия проекта.
#
# Источник:
#
#   файл VERSION в корне проекта.
#
# Если файл отсутствует,
# используется значение по умолчанию.
#

if [[ -f "${LSM_ROOT}/VERSION" ]]; then


    PROJECT_VERSION="$(tr -d '\r\n' < "${LSM_ROOT}/VERSION")"


else


    PROJECT_VERSION="${PROJECT_VERSION:-0.1.0}"


fi



export PROJECT_VERSION



#
# Обработчик критических ошибок.
#
# Используется совместно с:
#
#   set -E
#   trap ERR
#
# При ошибке:
#
#   - фиксирует строку;
#   - записывает сообщение в лог;
#   - завершает установку.
#

trap_install_error()
{

    local exit_code=$?

    local line_no=$1



    echo



    log_error "${INSTALL_COMPONENT}" \
        "Критическая ошибка установки. Строка: ${line_no}, код: ${exit_code}"



    log_error "${INSTALL_COMPONENT}" \
        "Установка Lite Server Monitor остановлена."



    exit "${exit_code}"

}



trap 'trap_install_error $LINENO' ERR



#
# Проверка прав root.
#
# Установка LSM требует:
#
#   - создания системных каталогов;
#   - установки пакетов;
#   - создания служб;
#   - изменения прав доступа.
#

if declare -f check_root >/dev/null 2>&1; then


    check_root


else


    #
    # Резервная проверка,
    # если common.sh не загрузился.
    #

    if [[ "${EUID}" -ne 0 ]]; then


        echo "Ошибка: установка требует права root."

        exit 1


    fi


fi



#
# Определение режима установки.
#
# Поддерживаются параметры:
#
#   --quiet
#   --non-interactive
#   -y
#
# Все они запускают автоматический режим.
#

NON_INTERACTIVE=false



if [[ "${1:-}" == "--quiet" ]] || \
   [[ "${1:-}" == "--non-interactive" ]] || \
   [[ "${1:-}" == "-y" ]]; then


    NON_INTERACTIVE=true


fi



#
# Загрузка списка доступных модулей.
#

registry_load_default



#
# Запуск мастера установки.
#
# В интерактивном режиме
# пользователь выбирает:
#
#   - режим установки;
#   - модули;
#   - уведомления;
#   - дополнительные параметры.
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
# Автоматическая установка.
#
# Используются параметры по умолчанию.
#

else



    log_info "${INSTALL_COMPONENT}" \
        "Запуск автоматической установки."



    INSTALL_MODE="standard"

    NOTIFICATION_METHOD="none"



    INSTALL_UPS=true

    UPS_PROFILE="default"



    DAILY_REPORT_ENABLED=true

    DAILY_REPORT_TIME="09:00"



    #
    # Выбор всех зарегистрированных модулей.
    #

    declare -a SELECTED_MODULES=()



    while read -r module; do


        [[ -z "${module}" ]] && continue



        SELECTED_MODULES+=("${module}")



    done < <(registry_list)



fi



#
# Начало установки.
#

log_info "${INSTALL_COMPONENT}" \
    "Lite Server Monitor v${PROJECT_VERSION}"



log_info "${INSTALL_COMPONENT}" \
    "Зарегистрированные модули:"


registry_list



#
# Последовательность этапов установки.
#
# Каждый файл содержит функцию:
#
#   step_<имя>
#
# Например:
#
#   04_configuration.sh
#
# вызывает:
#
#   step_configuration
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



    #
    # Загружаем файл этапа.
    #

    source "${step_path}"



    #
    # Формируем имя функции.
    #
    # Например:
    #
    # 01_environment.sh
    #
    # превращается:
    #
    # step_environment
    #

    step_name="$(
        echo "${step_script}" |
        sed -E 's/^[0-9]+_//; s/\.sh$//'
    )"



    step_function="step_${step_name}"



    #
    # Запускаем функцию этапа.
    #

    if declare -f "${step_function}" >/dev/null 2>&1; then


        "${step_function}"



    else


        log_warn "${INSTALL_COMPONENT}" \
            "Функция этапа отсутствует: ${step_function}"



    fi



done



#
# Создание CLI-команды LSM.
#
# CLI всегда должен указывать на установленную
# копию LSM, а не на временный каталог bootstrap.
#

deploy_create_symlink \
    "/opt/lsm/bin/lsm" \
    "/usr/local/bin/lsm"



#
# Завершение установки.
#

echo



log_success "${INSTALL_COMPONENT}" \
    "Lite Server Monitor v${PROJECT_VERSION} установлен успешно."



log_info "${INSTALL_COMPONENT}" \
    "Команда управления: lsm help"
