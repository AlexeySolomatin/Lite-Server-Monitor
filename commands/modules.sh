#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Управление модулями мониторинга
#
# Путь:
#   commands/modules.sh
#
# Назначение:
#   Просмотр списка, включение и отключение модулей мониторинга LSM.
#
# ==============================================================================


set -Eeuo pipefail



#
# Определение корня проекта
#

LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

export LSM_ROOT



#
# Загрузка библиотек
#

# shellcheck source=/dev/null
source "${LSM_ROOT}/lib/core/common.sh"

# shellcheck source=/dev/null
source "${LSM_ROOT}/lib/core/logging.sh"

# shellcheck source=/dev/null
source "${LSM_ROOT}/lib/installer/module_loader.sh"

# shellcheck source=/dev/null
source "${LSM_ROOT}/lib/installer/registry.sh"

# shellcheck source=/dev/null
source "${LSM_ROOT}/lib/installer/modules.sh"



#
# Помощник прав доступа.
#
# Read-only подкоманды (list/available/status/help) работают
# без root. Изменяющие (install/remove/enable/disable) требуют
# root и при необходимости перезапускают СЕБЯ через sudo,
# сохраняя все аргументы.
#

modules_require_root()
{
    if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
        return 0
    fi

    if command -v sudo >/dev/null 2>&1; then

        printf "\033[1;33m[i] [MODULES]\033[0m Для операции '%s' требуются права root. Перезапуск через sudo...\n" \
            "${1:-}"

        exec sudo -- bash "${BASH_SOURCE[0]}" "$@"

    fi

    log_error \
        "${MODULES_COMPONENT}" \
        "Операция '${1:-}' требует прав root, но sudo не найден."

    exit 1
}



#
# Загрузка реестра доступных модулей.
#
# Без сканирования массивы реестра пусты:
# команды available/list вернули бы пустой список.
#

modules_registry_load()
{
    if declare -f registry_load_default >/dev/null 2>&1; then

        registry_load_default quiet

    elif declare -f registry_scan >/dev/null 2>&1; then

        registry_scan

    fi
}



#
# Помощь
#

modules_help()
{

cat <<EOF

Использование:

  lsm modules <команда> [модуль]


Команды:

  list
      Список установленных модулей


  available
      Список доступных модулей


  install <module>
      Установить модуль


  remove <module>
      Удалить модуль


  status <module>
      Показать состояние модуля


  enable <module>
      Включить модуль


  disable <module>
      Отключить модуль


Примеры:

  lsm modules list

  lsm modules available

  lsm modules install docker

  lsm modules status smart


EOF

}



#
# Список доступных модулей
#

modules_available()
{

    modules_registry_load


    echo

    echo "Доступные модули:"

    echo


    registry_list


    echo

}



#
# Основной обработчик
#

main()
{


    local command="${1:-help}"

    local module="${2:-}"



    case "${command}" in


        list)


            modules_registry_load


            echo

            echo "Установленные модули:"

            echo


            modules_installed_list

        ;;



        available)


            modules_available

        ;;



        install)


            modules_require_root "${command}" "$@"


            if [[ -z "${module}" ]]; then

                log_error \
                "${MODULES_COMPONENT}" \
                "Не указан модуль для установки."

                exit 1

            fi


            modules_install "${module}"

        ;;



        remove)


            modules_require_root "${command}" "$@"


            if [[ -z "${module}" ]]; then

                log_error \
                "${MODULES_COMPONENT}" \
                "Не указан модуль для удаления."

                exit 1

            fi


            modules_remove "${module}"

        ;;



        status)


            if [[ -z "${module}" ]]; then

                log_error \
                "Не указан модуль."

                exit 1

            fi


            modules_status "${module}"

        ;;



        enable)


            modules_require_root "${command}" "$@"


            if [[ -z "${module}" ]]; then

                log_error \
                "${MODULES_COMPONENT}" \
                "Не указан модуль."

                exit 1

            fi


            modules_enable "${module}"

        ;;



        disable)


            modules_require_root "${command}" "$@"


            if [[ -z "${module}" ]]; then

                log_error \
                "${MODULES_COMPONENT}" \
                "Не указан модуль."

                exit 1

            fi


            modules_disable "${module}"

        ;;



        help|-h|--help)


            modules_help

        ;;



        *)


            log_error \
            "Неизвестная команда: ${command}"


            modules_help


            exit 1

        ;;


    esac


}



main "$@"
