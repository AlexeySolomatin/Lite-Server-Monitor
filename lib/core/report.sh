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
#   Формирование человекочитаемого отчета LSM.
#
# Ответственность:
#
#   report.sh:
#       - собирает данные;
#       - форматирует отчет;
#       - вызывает API модулей.
#
#   logging.sh:
#       - журналирование событий.
#
#   module_api.sh:
#       - взаимодействие с модулями.
#
# ==============================================================================


set -Eeuo pipefail



#
# Защита от повторной загрузки
#

[[ -n "${LSM_REPORT_LOADED:-}" ]] && return 0

readonly LSM_REPORT_LOADED=1



readonly REPORT_COMPONENT="REPORT"



#
# Определение корня LSM
#

LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"



#
# Загрузка UI
#

if [[ -f "${LSM_ROOT}/lib/core/ui.sh" ]]; then

    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/core/ui.sh"

fi



#
# Загрузка logging
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
# Fallback UI
#

if ! declare -f ui_section >/dev/null 2>&1; then

    ui_section()
    {
        echo
        echo "--- $1 ---"
    }


fi



if ! declare -f ui_separator >/dev/null 2>&1; then

    ui_separator()
    {
        echo "============================================================"
    }

fi




# ==============================================================================
# Заголовок отчета
# ==============================================================================

report_get_header()
{

    local hostname_str
    local uptime_str
    local load_avg
    local date_str



    hostname_str="$(
        hostname -f 2>/dev/null \
        || hostname 2>/dev/null \
        || echo "unknown"
    )"



    uptime_str="$(
        uptime -p 2>/dev/null \
        || uptime \
        || echo "Н/Д"
    )"



    if [[ -r /proc/loadavg ]]; then

        load_avg="$(cut -d' ' -f1-3 /proc/loadavg)"

    else

        load_avg="Н/Д"

    fi



    date_str="$(date '+%Y-%m-%d %H:%M:%S %Z')"



cat <<EOF
$(ui_separator)

 LITE SERVER MONITOR (LSM)
 Ежедневный системный отчет

 Хост            : ${hostname_str}
 Дата            : ${date_str}
 Время работы    : ${uptime_str}
 Load Average    : ${load_avg}

$(ui_separator)

EOF

}



# ==============================================================================
# Системные показатели
# ==============================================================================

report_get_system_metrics()
{

    ui_section \
        "Использование оперативной памяти"


    free -h 2>/dev/null \
        || echo "Нет данных"



    ui_section \
        "Использование файловых систем"


    df -h \
        -x tmpfs \
        -x devtmpfs \
        -x squashfs \
        2>/dev/null \
        || echo "Нет данных"



    ui_section \
        "Топ процессов CPU"



    ps aux \
        --sort=-%cpu \
        2>/dev/null \
        | head -n 6 \
        || true



    ui_section \
        "Топ процессов RAM"



    ps aux \
        --sort=-%mem \
        2>/dev/null \
        | head -n 6 \
        || true

}



# ==============================================================================
# Проверка активных предупреждений
# ==============================================================================

report_get_active_alerts()
{

    local state_dir

    state_dir="${LSM_STATE_DIR:-/var/lib/lsm/state}"



    ui_section \
        "Активные предупреждения"



    if [[ ! -d "${state_dir}" ]]; then

        echo "State каталог отсутствует."

        return 0

    fi



    local found=false
    local file



    while read -r file
    do


        found=true


        local module

        module="$(basename "${file}" .state)"


        echo
        echo "Модуль: ${module}"


        cat "${file}"


    done < <(
        find "${state_dir}" \
            -name "*.state" \
            -type f \
            2>/dev/null \
            | sort
    )



    if [[ "${found}" == "false" ]]; then

        echo "Активных предупреждений нет."

    fi

}



# ==============================================================================
# Отчет модулей LSM
# ==============================================================================

report_collect_modules()
{

    ui_section \
        "Отчеты модулей LSM"



    if declare -f module_api_report_all >/dev/null 2>&1; then


        module_api_report_all


    else


        echo "Module API недоступен."


    fi

}



# ==============================================================================
# Полный отчет
# ==============================================================================

report_generate_full()
{

    local current_ver


    current_ver="${PROJECT_VERSION:-${LSM_VERSION:-unknown}}"



    report_get_header



    report_get_system_metrics



    report_get_active_alerts



    report_collect_modules



    echo



    ui_separator



    echo

    echo "Отчет сформирован LSM v${current_ver}"

    ui_separator

}
