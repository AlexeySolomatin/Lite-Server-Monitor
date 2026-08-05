#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Библиотека: Генератор системных отчетов
#
# Путь:
#   lib/core/report.sh
#
# Назначение:
#   Формирование системного отчета LSM.
#
# Возможности:
#   - информация о сервере;
#   - системные метрики;
#   - активные предупреждения;
#   - отчеты установленных модулей через Module API.
# ==============================================================================


if [[ -n "${_LSM_LIB_REPORT_SH:-}" ]]; then
    return 0
fi

_LSM_LIB_REPORT_SH=1


set -Eeuo pipefail



#
# Определение корня LSM
#

LSM_ROOT="${LSM_ROOT:-/opt/lsm}"



#
# Подключение Module API
#

if [[ -f "${LSM_ROOT}/lib/core/module_api.sh" ]]; then

    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/core/module_api.sh"

fi



readonly REPORT_COMPONENT="REPORT"




# ------------------------------------------------------------------------------
# Заголовок отчета
# ------------------------------------------------------------------------------

report_get_header()
{
    local hostname_str
    local uptime_str
    local load_avg
    local date_str


    hostname_str="$(
        hostname -f 2>/dev/null ||
        hostname 2>/dev/null ||
        echo "localhost"
    )"


    uptime_str="$(
        uptime -p 2>/dev/null ||
        uptime 2>/dev/null ||
        echo "Н/Д"
    )"



    if [[ -r /proc/loadavg ]]; then

        load_avg="$(cut -d' ' -f1-3 /proc/loadavg)"

    else

        load_avg="Н/Д"

    fi



    date_str="$(date '+%Y-%m-%d %H:%M:%S %Z')"



cat <<EOF
==============================================================================
 LITE SERVER MONITOR (LSM)
 ЕЖЕДНЕВНЫЙ СИСТЕМНЫЙ ОТЧЕТ
==============================================================================

 Имя хоста        : ${hostname_str}
 Дата и время     : ${date_str}
 Время работы     : ${uptime_str}
 Средняя нагрузка : ${load_avg}

==============================================================================
EOF

}




# ------------------------------------------------------------------------------
# Системные показатели
# ------------------------------------------------------------------------------

report_get_system_metrics()
{


echo
echo "--- Использование оперативной памяти ---"


if command -v free >/dev/null 2>&1; then

    free -h

else

    echo "Команда free недоступна."

fi




echo
echo "--- Использование файловых систем ---"


if command -v df >/dev/null 2>&1; then

    df -h \
        -x tmpfs \
        -x devtmpfs \
        -x squashfs

else

    echo "Команда df недоступна."

fi




echo
echo "--- Топ процессов CPU ---"


ps aux \
    --sort=-%cpu \
    2>/dev/null \
    | head -n 6 \
    || true




echo
echo "--- Топ процессов RAM ---"


ps aux \
    --sort=-%mem \
    2>/dev/null \
    | head -n 6 \
    || true


}




# ------------------------------------------------------------------------------
# Активные предупреждения
# ------------------------------------------------------------------------------

report_get_active_alerts()
{

    local state_dir

    state_dir="${LSM_STATE_DIR:-/var/lib/lsm/state}"



    local found=false



echo
echo "--- Активные предупреждения LSM ---"



if [[ ! -d "${state_dir}" ]]; then

    echo "  State-каталог отсутствует."

    return 0

fi



while read -r state_file
do


    [[ -f "${state_file}" ]] || continue


    found=true


    local module

    local data


    module="$(basename "${state_file}" .state)"


    data="$(cat "${state_file}" 2>/dev/null || true)"



    echo "  [ТРЕВОГА] ${module}: ${data}"


done < <(
    find "${state_dir}" \
        -name "*.state" \
        -type f \
        2>/dev/null
)



if [[ "${found}" == "false" ]]; then

    echo "  Активных предупреждений нет."

fi

}




# ------------------------------------------------------------------------------
# Отчет установленных модулей
# ------------------------------------------------------------------------------

report_collect_modules()
{


echo
echo "--- Отчеты модулей LSM ---"



#
# Проверяем наличие Module API
#

if ! declare -f module_api_report_all >/dev/null 2>&1; then


    echo "  Module API недоступен."


    return 0

fi



#
# Передаем управление API модулей
#

module_api_report_all


}





# ------------------------------------------------------------------------------
# Полный отчет
# ------------------------------------------------------------------------------

report_generate_full()
{


local current_ver

current_ver="${PROJECT_VERSION:-${LSM_VERSION:-0.1.1-alpha}}"



report_get_header


report_get_system_metrics


report_get_active_alerts


report_collect_modules



cat <<EOF


==============================================================================
 Отчет сформирован Lite Server Monitor v${current_ver}
==============================================================================

EOF

}
