#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Команда управления конфигурацией
#
# Путь:
#   commands/config.sh
#
# Назначение:
#   Просмотр конфигурационных файлов LSM.
#
# Использование:
#
#   lsm config
#       вывод списка всех конфигурационных файлов;
#
#   lsm config show <файл>
#       вывод содержимого указанного файла
#       (имя без каталога, например: config.conf).
#
# Каталог конфигурации:
#
#   /etc/lsm (переопределяется переменной LSM_CONFIG_DIR)
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

for library in \
    "lib/core/common.sh" \
    "lib/core/logging.sh"
do

    if [[ -f "${LSM_ROOT}/${library}" ]]; then

        # shellcheck source=/dev/null
        source "${LSM_ROOT}/${library}"

    fi

done



readonly CONFIG_COMPONENT="CONFIG"



#
# Каталог конфигурации
#

CONFIG_DIR="${LSM_CONFIG_DIR:-/etc/lsm}"



#
# Проверка существования каталога конфигурации
#

if [[ ! -d "${CONFIG_DIR}" ]]; then

    log_error \
        "${CONFIG_COMPONENT}" \
        "Каталог конфигурации не найден: ${CONFIG_DIR}"

    exit 1

fi



#
# Список конфигурационных файлов
#

config_list()
{

    log_info \
        "${CONFIG_COMPONENT}" \
        "Конфигурационные файлы: ${CONFIG_DIR}"


    local file


    while IFS= read -r file
    do

        log_success \
            "${CONFIG_COMPONENT}" \
            "Конфигурационный файл: ${file}"

    done < <(
        find "${CONFIG_DIR}" -type f 2>/dev/null | sort
    )

}



#
# Просмотр конфигурационного файла
#

config_show()
{
    local name="${1:-}"


    if [[ -z "${name}" ]]; then

        log_error \
            "${CONFIG_COMPONENT}" \
            "Не указано имя файла. Пример: lsm config show config.conf"

        return 1

    fi


    local path="${CONFIG_DIR}/${name}"


    if [[ ! -f "${path}" ]]; then

        log_error \
            "${CONFIG_COMPONENT}" \
            "Файл не найден: ${path}"

        return 1

    fi


    cat "${path}"

}



#
# Основной обработчик
#

main()
{

    local command="${1:-list}"


    case "${command}" in


        list)
            config_list
            ;;


        show)
            shift || true
            config_show "${1:-}"
            ;;


        help|-h|--help)
            sed -n '/^# Использование:/,/^# ===/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            ;;


        *)
            log_error \
                "${CONFIG_COMPONENT}" \
                "Неизвестная команда: ${command}"
            exit 1
            ;;

    esac

}


main "$@"
