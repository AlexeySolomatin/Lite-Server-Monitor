#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# CLI Команда: Генератор отчетов
#
# Путь:
#   commands/report.sh
#
# Назначение:
#
#   Создание системного отчета LSM.
#
# Возможности:
#
#   lsm report
#       вывод отчета в терминал
#
#   lsm report --save
#       сохранение отчета в файл
#
#   lsm report --send
#       отправка через систему уведомлений
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
    "lib/core/module_api.sh" \
    "lib/core/report.sh"
do

    if [[ -f "${LSM_ROOT}/${library}" ]]; then

        # shellcheck source=/dev/null
        source "${LSM_ROOT}/${library}"

    fi

done



readonly REPORT_COMPONENT="REPORT"



#
# Параметры
#

SEND_NOTIFICATION=false

SAVE_REPORT=false



#
# Каталог хранения отчетов
#

LSM_REPORT_DIR="${LSM_REPORT_DIR:-/var/lib/lsm/reports}"



#
# Разбор аргументов
#

for arg in "$@"
do

    case "${arg}" in


        --send|-s)

            SEND_NOTIFICATION=true

            ;;


        --save|-o)

            SAVE_REPORT=true

            ;;


    esac

done



#
# Проверка API отчета
#

if ! declare -f report_generate_full >/dev/null 2>&1; then


    log_error \
        "${REPORT_COMPONENT}" \
        "Функция генерации отчета недоступна."


    exit 1

fi



#
# Генерация отчета
#

report_content="$(
    report_generate_full
)" || {


    log_error \
        "${REPORT_COMPONENT}" \
        "Ошибка формирования отчета."


    exit 1

}



#
# Проверка результата
#

if [[ -z "${report_content}" ]]; then


    log_error \
        "${REPORT_COMPONENT}" \
        "Отчет пустой."


    exit 1

fi



#
# Сохранение отчета
#

if [[ "${SAVE_REPORT}" == "true" ]]; then


    mkdir -p "${LSM_REPORT_DIR}"



    REPORT_FILE="${LSM_REPORT_DIR}/lsm-report-$(date +%F_%H-%M-%S).txt"



    printf "%s\n" \
        "${report_content}" \
        > "${REPORT_FILE}"



    chmod 640 "${REPORT_FILE}"



    log_success \
        "${REPORT_COMPONENT}" \
        "Отчет сохранен: ${REPORT_FILE}"

fi



#
# Отправка уведомления
#

if [[ "${SEND_NOTIFICATION}" == "true" ]]; then


    notify_script="${LSM_ROOT}/lib/notifications/notify.sh"



    if [[ ! -x "${notify_script}" ]]; then


        log_error \
            "${REPORT_COMPONENT}" \
            "Система уведомлений недоступна."


        exit 1


    fi



    "${notify_script}" \
        "daily_report" \
        "OK" \
        "${report_content}"



    log_success \
        "${REPORT_COMPONENT}" \
        "Отчет отправлен."



fi



#
# Если нет сохранения и отправки,
# выводим отчет пользователю
#

if [[ "${SAVE_REPORT}" == "false" &&
      "${SEND_NOTIFICATION}" == "false" ]]; then



    ui_section \
        "Отчет Lite Server Monitor"



    printf "%s\n" \
        "${report_content}"

fi
