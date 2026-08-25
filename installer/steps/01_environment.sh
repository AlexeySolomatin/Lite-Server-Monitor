#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Шаг 01: Проверка окружения
#
# Путь:
#   installer/steps/01_environment.sh
#
# Назначение:
#   Проверка системных требований перед установкой LSM:
#
#   - права суперпользователя;
#   - поддерживаемая операционная система;
#   - версия Bash;
#   - наличие apt-get;
#   - архитектура процессора;
#   - доступ в Интернет;
#   - объем оперативной памяти;
#   - свободное дисковое пространство;
#   - права доступа к системным каталогам.
#
# ==============================================================================

set -Eeuo pipefail


readonly ENV_COMPONENT="ENVIRONMENT"



step_environment()
{

    print_section "Проверка окружения"



    #
    # Права суперпользователя
    #

    if ! is_root; then

        log_error "${ENV_COMPONENT}" \
            "Установщик необходимо запускать от имени root."

        return 1

    fi


    log_success "${ENV_COMPONENT}" \
        "Запуск выполнен от имени root."



    #
    # Поддерживаемая операционная система
    #

    if ! is_supported_os; then

        log_error "${ENV_COMPONENT}" \
            "Неподдерживаемая операционная система."

        return 1

    fi


    log_success "${ENV_COMPONENT}" \
        "Обнаружена поддерживаемая операционная система."



    #
    # Версия Bash
    #

    if (( BASH_VERSINFO[0] < 5 )); then

        log_error "${ENV_COMPONENT}" \
            "Требуется Bash версии 5.0 или новее."

        return 1

    fi


    log_success "${ENV_COMPONENT}" \
        "Версия Bash: ${BASH_VERSION}"



    #
    # Пакетный менеджер APT
    #

    if ! command_exists apt-get; then

        log_error "${ENV_COMPONENT}" \
            "apt-get не найден."

        return 1

    fi


    log_success "${ENV_COMPONENT}" \
        "Пакетный менеджер APT найден."



    #
    # Архитектура
    #

    local architecture

    architecture="$(uname -m)"


    case "${architecture}" in

        x86_64|aarch64)

            log_success "${ENV_COMPONENT}" \
                "Поддерживаемая архитектура: ${architecture}"

            ;;


        *)

            log_error "${ENV_COMPONENT}" \
                "Неподдерживаемая архитектура: ${architecture}"

            return 1

            ;;

    esac



    #
    # Интернет
    #

    if has_internet; then


        log_success "${ENV_COMPONENT}" \
            "Интернет-соединение доступно."


    else


        log_warn "${ENV_COMPONENT}" \
            "Интернет-соединение недоступно."


    fi



    #
    # Оперативная память
    #

    local memory_mb

    memory_mb="$(
        awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo
    )"


    memory_mb="${memory_mb:-0}"



    if (( memory_mb < 512 )); then


        log_error "${ENV_COMPONENT}" \
            "Требуется не менее 512 МБ ОЗУ. Доступно: ${memory_mb} МБ"


        return 1

    fi



    log_success "${ENV_COMPONENT}" \
        "Доступно ОЗУ: ${memory_mb} МБ"



    #
    # Дисковое пространство
    #

    local free_mb


    free_mb="$(
        df -Pm / |
        awk 'NR==2 {print $4}'
    )"


    free_mb="${free_mb:-0}"



    if (( free_mb < 1024 )); then


        log_error "${ENV_COMPONENT}" \
            "Требуется не менее 1 ГБ свободного дискового пространства. Доступно: ${free_mb} МБ"


        return 1

    fi



    log_success "${ENV_COMPONENT}" \
        "Свободно на диске: ${free_mb} МБ"



    #
    # Каталоги, доступные для записи
    #

    for dir in /opt /etc /var; do


        if [[ ! -w "${dir}" ]]; then


            log_error "${ENV_COMPONENT}" \
                "Каталог недоступен для записи: ${dir}"


            return 1


        fi


    done



    log_success "${ENV_COMPONENT}" \
        "Права доступа к файловой системе в порядке."



    #
    # Проверка окружения завершена
    #

    log_success "${ENV_COMPONENT}" \
        "Проверка окружения успешно завершена."


    return 0

}
