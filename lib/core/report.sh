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
#   Формирование человекочитаемого системного отчета LSM.
#
# Ответственность:
#
#   report.sh:
#       - собирает системные показатели;
#       - отображает активные состояния уведомлений;
#       - получает отчеты установленных модулей;
#       - форматирует итоговый отчет.
#
#   logging.sh:
#       - журналирование событий LSM.
#
#   module_api.sh:
#       - взаимодействие с модулями мониторинга.
#
# ВАЖНО:
#
#   Файлы:
#
#       /var/lib/lsm/state/*.state
#
#   являются состоянием системы уведомлений и управляются notify.sh.
#
#   Формат state-файла:
#
#       <unix_timestamp>|<LEVEL>
#
#   Например:
#
#       1754395200|CRITICAL
#
#   report.sh НЕ изменяет и НЕ удаляет state-файлы.
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
# Корень LSM
#

LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

export LSM_ROOT



#
# Каталог состояния
#
# Совпадает с каталогом, который использует notify.sh.
#

LSM_STATE_DIR="${LSM_STATE_DIR:-/var/lib/lsm/state}"



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



# ==============================================================================
# Внутренние функции форматирования отчета
# ==============================================================================

#
# Для системного отчета намеренно НЕ используется ui_section().
#
# Причина:
#
# commands/report.sh сначала генерирует отчет через command substitution:
#
#     report_content="$(report_generate_full)"
#
# В этот момент colors.sh мог быть загружен тогда, когда stdout еще являлся
# TTY. Поэтому ANSI-коды могли попасть внутрь самого отчета.
#
# Отчет должен оставаться чистым текстовым документом:
#
#   - пригодным для сохранения;
#   - пригодным для отправки;
#   - пригодным для просмотра через cat/less;
#   - пригодным для автоматической обработки.
#

report_section()
{
    local title="${1:-}"

    printf "\n"
    printf -- "------------------------------------------------------------------------------\n"
    printf " %s\n" "${title}"
    printf -- "------------------------------------------------------------------------------\n"
}



#
# Разделитель отчета
#

report_separator()
{
    printf -- "==============================================================================\n"
}



# ==============================================================================
# Заголовок отчета
# ==============================================================================

report_get_header()
{
    #
    # Все переменные инициализируются сразу: под set -u обращение
    # к объявленному, но не присвоенному local дает фатальную ошибку
    # "unbound variable". Присваивания однострочные: backslash-переносы
    # внутри $() в файлах с CRLF ломают парсинг.
    #

    local hostname_str=""
    local uptime_str=""
    local load_avg=""
    local date_str=""
    local current_ver=""

    hostname_str="$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo "unknown")"

    uptime_str="$(uptime -p 2>/dev/null || uptime 2>/dev/null || echo "НД")"

    if [[ -r /proc/loadavg ]]; then

        load_avg="$(awk '{print $1, $2, $3}' /proc/loadavg)"

    else

        load_avg="НД"

    fi

    date_str="$(date '+%Y-%m-%d %H:%M:%S %Z')"

    current_ver="${PROJECT_VERSION:-${LSM_VERSION:-unknown}}"

    report_separator



    cat <<EOF
 LITE SERVER MONITOR (LSM)
 Системный диагностический отчет

 Версия LSM       : ${current_ver}
 Хост             : ${hostname_str}
 Дата формирования : ${date_str}
 Время работы     : ${uptime_str}
 Load Average     : ${load_avg}

EOF



    report_separator

}



# ==============================================================================
# Системные показатели
# ==============================================================================



# ==============================================================================
# Визуальный индикатор заполненности.
#
# Аргументы:
#
#   $1 - процент (0-100, значения больше 100 обрезаются);
#   $2 - ширина бара в символах (по умолчанию 20).
#
# Вывод:
#
#   [██████░░░░░░░░░░░░░░]  30%
# ==============================================================================

report_bar()
{
    local pct="${1:-0}"
    local width="${2:-20}"

    local i
    local filled
    local empty
    local bar=""

    if [[ ! "${pct}" =~ ^[0-9]+$ ]]; then

        pct=0

    fi

    (( pct > 100 )) && pct=100

    filled=$(( pct * width / 100 ))

    empty=$(( width - filled ))

    for (( i = 0; i < filled; i++ )); do

        bar+="█"

    done

    for (( i = 0; i < empty; i++ )); do

        bar+="░"

    done

    printf '[%s] %3d%%' "${bar}" "${pct}"
}



# ==============================================================================
# Системные показатели.
#
# Компактная визуализация вместо сырых выводов free/df/ps:
#
#   - бары загрузки CPU, памяти, swap;
#   - ровная таблица файловых систем с барами;
#   - компактные топ-5 процессов по CPU и по памяти.
# ==============================================================================

report_get_system_metrics()
{
    local mem_total_kb
    local mem_avail_kb
    local mem_used_kb
    local mem_pct
    local mem_used_h
    local mem_total_h
    local mem_avail_h

    local swap_total_kb
    local swap_free_kb
    local swap_used_kb
    local swap_pct
    local swap_used_h
    local swap_total_h

    local cores
    local load1
    local load_pct

    human_kb()
    {
        awk -v k="$1" 'BEGIN {
            if (k >= 1048576) printf "%.1f GiB", k/1048576;
            else if (k >= 1024) printf "%.1f MiB", k/1024;
            else printf "%d KiB", k;
        }'
    }

    report_section \
        "Ресурсы системы"

    printf '\n'

    load1="н/д"
    cores=1
    load_pct=0

    if [[ -r /proc/loadavg ]]; then

        load1="$(awk '{print $1}' /proc/loadavg)"

    fi

    cores="$(nproc 2>/dev/null || echo 1)"

    if [[ "${load1}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then

        load_pct="$(awk -v l="${load1}" -v c="${cores}" 'BEGIN { p = int(l * 100 / c); if (p > 100) p = 100; print p }')"

    fi

    printf '  Загрузка CPU  %s\n' \
        "$(report_bar "${load_pct}" 14)  (load ${load1}, яд.: ${cores})"

    mem_pct=0
    mem_used_h="н/д"
    mem_total_h="н/д"
    mem_avail_h="н/д"

    if [[ -r /proc/meminfo ]]; then

        mem_total_kb="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
        mem_avail_kb="$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)"

        if [[ -z "${mem_avail_kb}" ]]; then

            mem_avail_kb="$(awk '/^MemFree:/ {print $2}' /proc/meminfo)"

        fi

        if [[ -n "${mem_total_kb}" && -n "${mem_avail_kb}" ]]; then

            mem_used_kb=$(( mem_total_kb - mem_avail_kb ))

            mem_pct=$(( mem_used_kb * 100 / mem_total_kb ))

            mem_used_h="$(human_kb "${mem_used_kb}")"
            mem_total_h="$(human_kb "${mem_total_kb}")"
            mem_avail_h="$(human_kb "${mem_avail_kb}")"

        fi

    fi

    printf '  Память        %s\n' \
        "$(report_bar "${mem_pct}" 14)  (${mem_used_h}/${mem_total_h}, своб. ${mem_avail_h})"

    swap_pct=0
    swap_used_h="н/д"
    swap_total_h="н/д"

    if [[ -r /proc/meminfo ]]; then

        swap_total_kb="$(awk '/^SwapTotal:/ {print $2}' /proc/meminfo)"

        swap_free_kb="$(awk '/^SwapFree:/ {print $2}' /proc/meminfo)"

        if [[ -n "${swap_total_kb}" && "${swap_total_kb}" -gt 0 ]] 2>/dev/null; then

            swap_used_kb=$(( swap_total_kb - swap_free_kb ))

            swap_pct=$(( swap_used_kb * 100 / swap_total_kb ))

            swap_used_h="$(human_kb "${swap_used_kb}")"
            swap_total_h="$(human_kb "${swap_total_kb}")"

        fi

    fi

    printf '  Swap          %s\n' \
        "$(report_bar "${swap_pct}" 14)  (${swap_used_h}/${swap_total_h})"

    printf '\n'

    report_section \
        "Файловые системы"

    printf '\n'

    printf '  %-22s %8s %8s %8s  %s\n' \
        "Точка монтирования" "Размер" "Занято" "Свободно" "Использование"

    printf '  %-22s %8s %8s %8s  %s\n' \
        "----------------------" "--------" "--------" "--------" "--------------"

    if command -v df >/dev/null 2>&1; then

        df -P 2>/dev/null \
        | awk '
            function h(n) {
                if (n >= 1048576) return sprintf("%.1fGiB", n/1048576)
                if (n >= 1024) return sprintf("%.1fMiB", n/1024)
                return n "KiB"
            }
            NR == 1 { next }
            {
                if (NF < 6) next
                pct = $5
                gsub(/%/, "", pct)
                if (pct !~ /^[0-9]+$/) next
                mp = $6
                for (i = 7; i <= NF; i++) mp = mp " " $i
                if (mp ~ /^\/(proc|sys|dev|run)(\/|$)/) next
                fs = $1
                if (fs ~ /^(proc|sysfs|devtmpfs|devpts|tmpfs|cgroup|cgroup2|pstore|bpf|debugfs|tracefs|securityfs|configfs|fusectl|mqueue|hugetlbfs|autofs|binfmt_misc|ramfs|overlay|squashfs|nsfs|efivarfs)/) next
                sz = h($2); us = h($3); av = h($4)
                bar = ""
                fill = int(pct * 14 / 100)
                for (i = 0; i < fill; i++) bar = bar "█"
                for (i = fill; i < 14; i++) bar = bar "░"
                printf "  %-22s %8s %8s %8s  [%s] %3d%%\n", mp, sz, us, av, bar, pct
            }' \
        || printf '%s\n' "Нет данных"

    else

        printf '%s\n' "Утилита df недоступна"

    fi

    printf '\n'

    report_section \
        "Процессы (топ-5)"

    printf '\n'

    if command -v ps >/dev/null 2>&1; then

        printf '  %s\n' "По загрузке CPU:"

        ps -eo pcpu=,user=,comm= --sort=-pcpu 2>/dev/null \
            | head -n 5 \
            | awk '{ printf "    %5.1f%%  %-12s %s\n", $1, $2, substr($0, index($0, $3)) }' \
            || true

        printf '\n  %s\n' "По потреблению памяти:"

        ps -eo pmem=,user=,comm= --sort=-pmem 2>/dev/null \
            | head -n 5 \
            | awk '{ printf "    %5.1f%%  %-12s %s\n", $1, $2, substr($0, index($0, $3)) }' \
            || true

    else

        printf '%s\n' "Утилита ps недоступна"

    fi

}
# ==============================================================================
# Преобразование Unix timestamp в человекочитаемую дату
# ==============================================================================

report_format_timestamp()
{
    local timestamp="${1:-}"



    if [[ ! "${timestamp}" =~ ^[0-9]+$ ]]; then

        printf '%s\n' "Н/Д"

        return 0

    fi



    date \
        -d "@${timestamp}" \
        '+%Y-%m-%d %H:%M:%S %Z' \
        2>/dev/null \
        || printf '%s\n' "Н/Д"

}



# ==============================================================================
# Проверка корректности state-файла уведомлений
# ==============================================================================

report_parse_state_file()
{
    local state_file="${1:-}"

    local state_data
    local timestamp
    local level



    [[ -f "${state_file}" ]] || return 1



    state_data="$(cat "${state_file}" 2>/dev/null || true)"



    [[ -n "${state_data}" ]] || return 1



    timestamp="${state_data%%|*}"
    level="${state_data#*|}"



    if [[ ! "${timestamp}" =~ ^[0-9]+$ ]]; then

        return 1

    fi



    case "${level}" in

        WARNING|CRITICAL)
            ;;

        *)
            return 1
            ;;

    esac



    printf '%s|%s\n' \
        "${timestamp}" \
        "${level}"

}



# ==============================================================================
# Активные предупреждения
#
# ВАЖНО:
#
# notify.sh является владельцем state-файлов.
#
# report.sh:
#
#   - только читает их;
#   - не изменяет;
#   - не удаляет;
#   - не создает.
#
# Формат:
#
#   /var/lib/lsm/state/<module>.state
#
#   <timestamp>|<LEVEL>
#
# ==============================================================================

report_get_active_alerts()
{
    local state_dir="${LSM_STATE_DIR}"



    report_section \
        "Активные предупреждения"



    if [[ ! -d "${state_dir}" ]]; then

        printf '%s\n' \
            "Каталог состояния уведомлений отсутствует: ${state_dir}"

        return 0

    fi



    local found=false
    local state_file
    local module
    local state_data
    local timestamp
    local level
    local formatted_time



    while IFS= read -r state_file
    do

        [[ -z "${state_file}" ]] && continue



        #
        # Поврежденный state-файл не должен ломать весь отчет.
        #

        if ! state_data="$(report_parse_state_file "${state_file}")"; then

            printf "  ! Некорректный state-файл: %s\n" \
                "${state_file}"

            continue

        fi



        timestamp="${state_data%%|*}"
        level="${state_data#*|}"



        module="$(basename "${state_file}" .state)"



        formatted_time="$(
            report_format_timestamp "${timestamp}"
        )"



        found=true



        printf "\n"
        printf "  Модуль       : %s\n" "${module}"
        printf "  Уровень      : %s\n" "${level}"
        printf "  Обнаружено   : %s\n" "${formatted_time}"



    done < <(
        find "${state_dir}" \
            -maxdepth 1 \
            -type f \
            -name "*.state" \
            -print \
            2>/dev/null \
            | sort
    )



    if [[ "${found}" == "false" ]]; then

        printf '%s\n' \
            "Активных предупреждений нет."

    fi

}



# ==============================================================================
# Отчеты модулей LSM
# ==============================================================================

report_collect_modules()
{

    report_section \
        "Отчеты модулей LSM"



    if ! declare -f module_api_report_all >/dev/null 2>&1; then

        printf '%s\n' \
            "Module API недоступен."

        return 0

    fi



    module_api_report_all

}



# ==============================================================================
# Полный отчет
# ==============================================================================

report_generate_full()
{
    local current_ver



    current_ver="${PROJECT_VERSION:-${LSM_VERSION:-unknown}}"



    #
    # Заголовок
    #

    report_get_header



    #
    # Системные показатели
    #

    report_get_system_metrics



    #
    # Активные alert-состояния
    #

    report_get_active_alerts



    #
    # Отчеты установленных модулей
    #

    report_collect_modules



    #
    # Завершение
    #

    printf "\n"

    report_separator

    printf "\n"

    printf "Отчет сформирован LSM v%s\n" \
        "${current_ver}"

    printf "\n"

    report_separator

}
