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
#   lsm report --save --send
#       сохранение и отправка отчета
#
# Ответственность:
#
#   commands/report.sh:
#       - разбирает параметры CLI;
#       - вызывает генератор отчета;
#       - сохраняет готовый отчет;
#       - передает готовый отчет системе уведомлений.
#
#   lib/core/report.sh:
#       - формирует содержимое отчета.
#
#   lib/core/ui.sh:
#       - отвечает за баннер и форматирование UI.
#
#   lib/core/logging.sh:
#       - отвечает за журналирование событий.
#
#   lib/core/module_api.sh:
#       - отвечает за взаимодействие с модулями.
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
# Порядок:
#
#   common
#       ↓
#   logging
#       ↓
#   ui
#       ↓
#   module_api
#       ↓
#   report
#
# Библиотеки имеют защиту от повторной загрузки,
# поэтому report.sh также может безопасно подключать
# необходимые ему зависимости.
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



#
# Компонент логирования.
#
# Используется REPORT_COMPONENT из lib/core/report.sh:
# объявление здесь второй раз упало бы по "readonly variable",
# так как библиотека уже подключена выше.
#



#
# Параметры запуска
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


        *)

            ;;

    esac

done



# ==============================================================================
# Проверка API отчета
# ==============================================================================

if ! declare -f report_generate_full >/dev/null 2>&1; then

    log_error \
        "${REPORT_COMPONENT}" \
        "Функция генерации отчета недоступна."

    exit 1

fi



# ==============================================================================
# Генерация отчета
# ==============================================================================

if ! report_content="$(
    report_generate_full
)"
then

    log_error \
        "${REPORT_COMPONENT}" \
        "Ошибка формирования отчета."

    exit 1

fi



#
# Проверка результата
#

if [[ -z "${report_content}" ]]; then

    log_error \
        "${REPORT_COMPONENT}" \
        "Генератор вернул пустой отчет."

    exit 1

fi



# ==============================================================================
# Сохранение отчета
# ==============================================================================

if [[ "${SAVE_REPORT}" == "true" ]]; then


    if ! mkdir -p "${LSM_REPORT_DIR}"; then

        log_error \
            "${REPORT_COMPONENT}" \
            "Не удалось создать каталог отчетов: ${LSM_REPORT_DIR}"

        exit 1

    fi



    REPORT_FILE="${LSM_REPORT_DIR}/lsm-report-$(date +%F_%H-%M-%S).txt"



    if ! printf '%s\n' "${report_content}" > "${REPORT_FILE}"; then

        log_error \
            "${REPORT_COMPONENT}" \
            "Не удалось сохранить отчет: ${REPORT_FILE}"

        exit 1

    fi



    if ! chmod 640 "${REPORT_FILE}"; then

        log_warn \
            "${REPORT_COMPONENT}" \
            "Не удалось установить права 640: ${REPORT_FILE}"

    fi



    log_success \
        "${REPORT_COMPONENT}" \
        "Отчет сохранен: ${REPORT_FILE}"

fi



# ==============================================================================
# Отправка уведомления
# ==============================================================================

if [[ "${SEND_NOTIFICATION}" == "true" ]]; then


    notify_script="${LSM_ROOT}/lib/notifications/notify.sh"



    if [[ ! -f "${notify_script}" ]]; then

        log_error \
            "${REPORT_COMPONENT}" \
            "Система уведомлений недоступна: ${notify_script}"

        exit 1

    fi



    # shellcheck source=/dev/null
    source "${notify_script}"



    if ! declare -f notify_raw >/dev/null 2>&1; then

        log_error \
            "${REPORT_COMPONENT}" \
            "Функция отправки уведомлений недоступна."

        exit 1

    fi



    #
    # Отчет доставляется всегда и не участвует
    # в логике подавления алертов (throttling),
    # поэтому используется notify_raw.
    #

    local_hostname="$(hostname -f 2>/dev/null || hostname)"


    if ! notify_raw \
        "📋 Ежедневный отчет LSM [${local_hostname}]" \
        "${report_content}"
    then

        log_error \
            "${REPORT_COMPONENT}" \
            "Не удалось отправить отчет."

        exit 1

    fi



    log_success \
        "${REPORT_COMPONENT}" \
        "Отчет отправлен."

fi



# ==============================================================================
# Вывод отчета в терминал
#
# Если пользователь не запросил --save и --send,
# отчет выводится непосредственно в терминал.
#
# Сам отчет уже содержит:
#
#   - баннер LSM;
#   - заголовок;
#   - системные показатели;
#   - активные предупреждения;
#   - отчеты модулей;
#   - завершающую информацию.
#
# Поэтому здесь не добавляем второй баннер или второй заголовок.
# ==============================================================================

if [[ "${SAVE_REPORT}" == "false" &&
      "${SEND_NOTIFICATION}" == "false" ]]; then

    #
    # Просмотр в терминале: чистим экран перед отчетом.
    # В пайпах и при перенаправлении в файл — нет.
    #

    if [[ -t 1 ]] && command -v clear >/dev/null 2>&1; then

        clear

    fi

    printf '%s\n' "${report_content}"

fi
