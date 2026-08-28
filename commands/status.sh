#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# CLI Команда: Статус системы
#
# Путь:
#   commands/status.sh
#
# Назначение:
#   Отображение текущего состояния установленной системы LSM.
#
#   Компактный одноэкранный вывод:
#
#     - сводка о сервере и версии;
#     - каталоги установки;
#     - установленные модули одной строкой;
#     - таблица таймеров systemd.
#
#   Очистка консоли выполняется только при интерактивном
#   терминале (TTY); при пайпах и перенаправлениях вывод
#   остается чистым от управляющих символов.
#
# ==============================================================================


set -Eeuo pipefail



#
# Определение корневого каталога LSM
#

if [[ -z "${LSM_ROOT:-}" ]]; then

    LSM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fi


export LSM_ROOT



#
# Загрузка библиотек LSM
#

for library in \
    "lib/core/common.sh" \
    "lib/core/logging.sh" \
    "lib/core/ui.sh"
do

    if [[ -f "${LSM_ROOT}/${library}" ]]; then

        # shellcheck source=/dev/null
        source "${LSM_ROOT}/${library}"

    fi

done



#
# Очистка экрана только в интерактивном терминале
#

if [[ -t 1 ]] && command -v clear >/dev/null 2>&1; then

    clear

fi



#
# Получение версии LSM
#

get_lsm_version()
{

    if [[ -f "${LSM_ROOT}/VERSION" ]]; then

        tr -d '\r\n' < "${LSM_ROOT}/VERSION"

    else

        echo "unknown"

    fi

}



#
# Состояние каталогов установки одной строкой
#

check_installation()
{
    local line=""

    local dir



    for dir in /etc/lsm /var/lib/lsm /var/log/lsm; do

        if [[ -d "${dir}" ]]; then

            line+="${CLR_GREEN}✓${CLR_RESET} ${dir}  "

        else

            line+="${CLR_RED}✗${CLR_RESET} ${dir}  "

        fi

    done


    printf '  %s\n' "${line}"
}



#
# Установленные модули одной строкой
#

show_modules()
{
    local state_dir="${LSM_STATE_DIR:-/var/lib/lsm}/modules"

    local names=""
    local count=0

    local file
    local module



    if [[ -d "${state_dir}" ]]; then

        while IFS= read -r file
        do

            [[ -z "${file}" ]] && continue

            module="$(basename "${file}" .installed)"

            names+="${module} "

            count=$((count + 1))

        done < <(
            find "${state_dir}" \
                -type f \
                -name "*.installed" \
                2>/dev/null \
                | sort
        )

    fi


    if (( count == 0 )); then

        printf '  %s\n' "Модули: не установлены"

    else

        printf '  Модули (%d): %s\n' "${count}" "${names% }"

    fi
}



#
# Таймеры systemd (стандартная таблица)
#

show_timers()
{
    printf '  Таймеры:\n'


    if ! command -v systemctl >/dev/null 2>&1; then

        printf '    Systemd недоступен\n'

        return 0

    fi


    local timers


    timers="$(
        systemctl list-timers \
            "lsm-*" \
            --no-pager \
            --no-legend \
            2>/dev/null \
            || true
    )"


    if [[ -z "${timers}" ]]; then

        printf '    Активные таймеры отсутствуют\n'

    else

        printf '%s\n' "${timers}" | sed 's/^/    /'

    fi
}



#
# Основная функция
#

show_status()
{
    ui_section "Состояние Lite Server Monitor"


    printf '\n'

    printf '  Версия    : %s\n' "$(get_lsm_version)"

    printf '  Сервер    : %s\n' "$(hostname)"

    printf '  Система   : %s\n' "$(uname -srm)"

    printf '  Аптайм    : %s\n' "$(uptime -p 2>/dev/null || uptime)"


    printf '\n'

    printf '  Установка:\n'

    check_installation


    printf '\n'

    show_modules


    printf '\n'


    show_timers

    printf '\n'
}



#
# Запуск команды
#

show_status
