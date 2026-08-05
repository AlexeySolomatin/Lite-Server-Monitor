#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Библиотека генерации системных отчетов
#
# Путь:
#   lib/core/report.sh
#
# Назначение:
#
#   Формирование человекочитаемого диагностического отчета LSM.
#
# Ответственность:
#
#   report.sh:
#       - собирает системные данные;
#       - форматирует отчет;
#       - отображает баннер LSM;
#       - отображает активные состояния;
#       - вызывает Module API для получения отчетов модулей.
#
#   ui.sh:
#       - баннер;
#       - заголовки разделов;
#       - пользовательское форматирование.
#
#   logging.sh:
#       - журналирование событий LSM.
#
#   module_api.sh:
#       - взаимодействие с модулями мониторинга.
#
# Структура состояния:
#
#   /var/lib/lsm/modules/*.installed
#       Состояние установки модулей.
#
#   /var/lib/lsm/state/*
#       Текущее состояние мониторинга / активные предупреждения.
#
# ==============================================================================


set -Eeuo pipefail



#
# Защита от повторной загрузки
#

[[ -n "${LSM_REPORT_LOADED:-}" ]] && return 0

readonly LSM_REPORT_LOADED=1



#
# Компонент
#

readonly REPORT_COMPONENT="REPORT"



#
# Определение корня LSM
#

LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

export LSM_ROOT



#
# Загрузка UI
#
# UI загружается первым, поскольку он также подключает colors.sh.
#

if [[ -f "${LSM_ROOT}/lib/core/ui.sh" ]]; then

    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/core/ui.sh"

fi



#
# Загрузка logging
#
# logging использует централизованные COLOR_* из colors.sh.
#

if [[ -f "${LSM_ROOT}/lib/core/logging.sh" ]]; then

    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/core/logging.sh"

fi



#
# Загрузка Module API
#

if [[ -f "${LSM_ROOT}/lib/core/module_api.sh" ]]; then

    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/core/module_api.sh"

fi



#
# Каталог состояния мониторинга
#
# Не путать с:
#
#   /var/lib/lsm/modules
#
# где хранятся *.installed.
#

: "${LSM_STATE_DIR:=/var/lib/lsm/state}"



# ==============================================================================
# Локальный разделитель отчета
#
# Не является частью общего UI API.
#
# Общий ui.sh отвечает за:
#
#   ui_banner()
#   ui_section()
#
# Форматирование внутреннего отчета остается здесь.
# ==============================================================================

report_separator()
{

    printf '%s\n' \
        "======================================================================"

}



# ==============================================================================
# Заголовок отчета
# ==============================================================================

report_get_header()
{

    local hostname_str
    local uptime_str
    local load_avg
    local date_str
    local current_ver



    hostname_str="$(
        hostname -f 2>/dev/null \
        || hostname 2>/dev/null \
        || printf '%s' "unknown"
    )"



    uptime_str="$(
        uptime -p 2>/dev/null \
        || uptime 2>/dev/null \
        || printf '%s' "Н/Д"
    )"



    if [[ -r /proc/loadavg ]]; then

        load_avg="$(awk '{print $1, $2, $3}' /proc/loadavg)"

    else

        load_avg="Н/Д"

    fi



    date_str="$(date '+%Y-%m-%d %H:%M:%S %Z')"



    current_ver="${PROJECT_VERSION:-${LSM_VERSION:-unknown}}"



    #
    # Используем единый баннер LSM из ui.sh.
    #

    if declare -f ui_banner >/dev/null 2>&1; then

        ui_banner

    fi



    report_separator



    printf '%s\n' \
        "                    ДИАГНОСТИЧЕСКИЙ ОТЧЕТ"



    report_separator



    printf '\n'
    printf 'Версия LSM        : %s\n' "${current_ver}"
    printf 'Хост              : %s\n' "${hostname_str}"
    printf 'Дата              : %s\n' "${date_str}"
    printf 'Время работы      : %s\n' "${uptime_str}"
    printf 'Load Average      : %s\n' "${load_avg}"



    printf '\n'

    report_separator

    printf '\n'

}



# ==============================================================================
# Системные показатели
# ==============================================================================

report_get_system_metrics()
{

    if declare -f ui_section >/dev/null 2>&1; then

        ui_section "Использование оперативной памяти"

    else

        printf '\n---> Использование оперативной памяти\n'

    fi



    if command -v free >/dev/null 2>&1; then

        free -h 2>/dev/null \
            || printf '%s\n' "Нет данных"

    else

        printf '%s\n' "Команда free недоступна"

    fi



    if declare -f ui_section >/dev/null 2>&1; then

        ui_section "Использование файловых систем"

    else

        printf '\n---> Использование файловых систем\n'

    fi



    if command -v df >/dev/null 2>&1; then

        df -h \
            -x tmpfs \
            -x devtmpfs \
            -x squashfs \
            2>/dev/null \
            || printf '%s\n' "Нет данных"

    else

        printf '%s\n' "Команда df недоступна"

    fi



    if declare -f ui_section >/dev/null 2>&1; then

        ui_section "Топ процессов CPU"

    else

        printf '\n---> Топ процессов CPU\n'

    fi



    if command -v ps >/dev/null 2>&1; then

        ps aux \
            --sort=-%cpu \
            2>/dev/null \
            | head -n 6 \
            || true

    else

        printf '%s\n' "Команда ps недоступна"

    fi



    if declare -f ui_section >/dev/null 2>&1; then

        ui_section "Топ процессов RAM"

    else

        printf '\n---> Топ процессов RAM\n'

    fi



    if command -v ps >/dev/null 2>&1; then

        ps aux \
            --sort=-%mem \
            2>/dev/null \
            | head -n 6 \
            || true

    else

        printf '%s\n' "Команда ps недоступна"

    fi



    printf '\n'

}



# ==============================================================================
# Активные состояния мониторинга
#
# Источник:
#
#   /var/lib/lsm/state/*
#
# Пустые файлы не считаются активными предупреждениями.
#
# Формат строки состояния может быть:
#
#   timestamp|message
#
# В таком случае в отчет выводится часть после первого "|".
#
# Если "|" отсутствует, выводится исходная строка.
# ==============================================================================

report_get_active_alerts()
{

    if declare -f ui_section >/dev/null 2>&1; then

        ui_section "Активные предупреждения"

    else

        printf '\n---> Активные предупреждения\n'

    fi



    if [[ ! -d "${LSM_STATE_DIR}" ]]; then

        printf '%s\n' \
            "Все системы работают штатно. Активных предупреждений нет."

        printf '\n'

        return 0

    fi



    local found=false
    local file
    local module
    local line
    local content



    while IFS= read -r -d '' file
    do

        #
        # Пустые state-файлы не являются активными предупреждениями.
        #

        [[ -s "${file}" ]] || continue



        found=true



        module="$(basename "${file}")"



        printf '\n'
        printf '[ТРЕВОГА] Модуль: %s\n' "${module}"



        #
        # Читаем состояние построчно.
        #

        while IFS= read -r line || [[ -n "${line}" ]]
        do

            [[ -n "${line}" ]] || continue



            #
            # Если используется формат:
            #
            # timestamp|message
            #
            # показываем только сообщение.
            #

            if [[ "${line}" == *"|"* ]]; then

                content="${line#*|}"

            else

                content="${line}"

            fi



            printf '  %s\n' "${content}"

        done < "${file}"



    done < <(
        find "${LSM_STATE_DIR}" \
            -type f \
            -print0 \
            2>/dev/null \
            | sort -z
    )



    if [[ "${found}" == "false" ]]; then

        printf '%s\n' \
            "Все системы работают штатно. Активных предупреждений нет."

    fi



    printf '\n'

}



# ==============================================================================
# Отчет модулей LSM
# ==============================================================================

report_collect_modules()
{

    if declare -f ui_section >/dev/null 2>&1; then

        ui_section "Отчеты модулей LSM"

    else

        printf '\n---> Отчеты модулей LSM\n'

    fi



    if declare -f module_api_report_all >/dev/null 2>&1; then

        module_api_report_all

    else

        printf '%s\n' \
            "Module API недоступен."

    fi



    printf '\n'

}



# ==============================================================================
# Полный отчет
# ==============================================================================

report_generate_full()
{

    local current_ver

    current_ver="${PROJECT_VERSION:-${LSM_VERSION:-unknown}}"



    #
    # Заголовок и единый баннер.
    #

    report_get_header



    #
    # Общие системные показатели.
    #

    report_get_system_metrics



    #
    # Текущее состояние мониторинга.
    #

    report_get_active_alerts



    #
    # Подробные отчеты установленных модулей.
    #

    report_collect_modules



    #
    # Завершение отчета.
    #

    report_separator

    printf '\n'
    printf 'Отчет сформирован LSM v%s\n' "${current_ver}"
    printf '\n'

    report_separator

}

