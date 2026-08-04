#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# CLI Команда: Генератор отчетов
#
# Назначение:
#   Создание диагностического отчета LSM.
#
# Возможности:
#   - вывод отчета в терминал;
#   - сохранение отчета в файл;
#   - отправка через систему уведомлений.
#
# Использование:
#
#   lsm report
#   lsm report --save
#   lsm report --send
#
# Путь:
#   commands/report.sh
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
    "lib/core/report.sh"
do

    if [[ -f "${LSM_ROOT}/${library}" ]]; then

        # shellcheck source=/dev/null
        source "${LSM_ROOT}/${library}"

    fi

done



readonly REPORT_COMPONENT="REPORT"



#
# Параметры запуска
#

SEND_NOTIFICATION=false
SAVE_REPORT=false



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


        *)

            ;;

    esac

done



#
# Проверка генератора
#

if ! declare -f report_generate_full >/dev/null 2>&1; then


    log_error \
        "${REPORT_COMPONENT}" \
        "Библиотека генерации отчета недоступна."


    exit 1


fi



#
# Создание отчета
#

report_content="$(
    report_generate_full
)"



#
# Сохранение отчета
#

if [[ "${SAVE_REPORT}" == "true" ]]; then


    REPORT_DIR="/var/lib/lsm/reports"


    mkdir -p "${REPORT_DIR}"


    REPORT_FILE="${REPORT_DIR}/lsm-report-$(date +%F_%H-%M-%S).txt"



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



    if [[ -x "${notify_script}" ]]; then


        "${notify_script}" \
            "daily_report" \
            "OK" \
            "${report_content}"



        log_success \
            "${REPORT_COMPONENT}" \
            "Отчет отправлен."


    else


        log_error \
            "${REPORT_COMPONENT}" \
            "Модуль уведомлений отсутствует."


        exit 1


    fi


else


    ui_section \
        "Отчет Lite Server Monitor"



    printf "%s\n" \
        "${report_content}"


fi
