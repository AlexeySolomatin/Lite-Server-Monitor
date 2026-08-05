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
    local hostname_str
    local uptime_str
    local load_avg
    local date_str
    local current_ver



    hostname_str="$(
        hostname -f 2>/dev/null \
            || hostname 2>/dev/null \
            || printf '%s\n' "unknown"
    )



    uptime_str="$(
        uptime -p 2>/dev/null \
            || uptime 2>/dev/null \
            || printf '%s\n' "Н/Д"
    )



    if [[ -r /proc/loadavg ]]; then

        load_avg="$(awk '{print $1, $2, $3}' /proc/loadavg)"

    else

        load_avg="Н/Д"

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

report_get_system_metrics()
{

    report_section \
        "Использование оперативной памяти"



    if command -v free >/dev/null 2>&1; then

        free -h 2>/dev/null || printf '%s\n' "Нет данных"

    else

        printf '%s\n' "Утилита free недоступна"

    fi



    report_section \
        "Использование файловых систем"



    if command -v df >/dev/null 2>&1; then

        df -h \
            -x tmpfs \
            -x devtmpfs \
            -x squashfs \
            2>/dev/null \
            || printf '%s\n' "Нет данных"

    else

        printf '%s\n' "Утилита df недоступна"

    fi



    report_section \
        "Топ процессов по CPU"



    if command -v ps >/dev/null 2>&1; then

        ps aux \
            --sort=-%cpu \
            2>/dev/null \
            | head -n 6 \
            || true

    else

        printf '%s\n' "Утилита ps недоступна"

    fi



    report_section \
        "Топ процессов по RAM"



    if command -v ps >/dev/null 2>&1; then

        ps aux \
            --sort=-%mem \
            2>/dev/null \
            | head -n 6 \
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
