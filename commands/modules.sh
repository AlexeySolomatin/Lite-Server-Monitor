#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Управление модулями мониторинга
# Путь: commands/modules.sh
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
source "${LSM_ROOT}/lib/installer/registry.sh"

# shellcheck source=/dev/null
source "${LSM_ROOT}/lib/installer/modules.sh"



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

    echo

    echo "Доступные модули:"

    echo


    modules_list


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


            echo

            echo "Установленные модули:"

            echo


            modules_installed_list

        ;;



        available)


            modules_available

        ;;



        install)


            if [[ -z "${module}" ]]; then

                log_error \
                "Не указан модуль для установки."

                exit 1

            fi


            modules_install "${module}"

        ;;



        remove)


            if [[ -z "${module}" ]]; then

                log_error \
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


            if [[ -z "${module}" ]]; then

                log_error \
                "Не указан модуль."

                exit 1

            fi


            modules_enable "${module}"

        ;;



        disable)


            if [[ -z "${module}" ]]; then

                log_error \
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
