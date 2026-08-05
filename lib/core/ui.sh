#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Библиотека пользовательского интерфейса и форматирования терминала
#
# Путь:
#   lib/core/ui.sh
#
# Назначение:
#   Общий слой отображения информации:
#
#   - баннер LSM;
#   - заголовки разделов;
#   - статусные сообщения;
#   - форматирование отчетов;
#   - управление цветами.
#
# Используется:
#   installer/
#   commands/
#   report.sh
#
# Требования:
#   Bash 4+
#
# ==============================================================================


set -Eeuo pipefail



#
# Защита от повторной загрузки
#

[[ -n "${LSM_UI_LOADED:-}" ]] && return 0

readonly LSM_UI_LOADED=1



#
# Определение корня проекта
#

LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"



#
# Версия LSM
#

if [[ -z "${PROJECT_VERSION:-}" ]]; then


    if [[ -f "${LSM_ROOT}/VERSION" ]]; then

        PROJECT_VERSION="$(tr -d '\r\n' < "${LSM_ROOT}/VERSION")"

    else

        PROJECT_VERSION="unknown"

    fi


    export PROJECT_VERSION

fi



#
# Подключение цветовой схемы
#

if [[ -f "${LSM_ROOT}/lib/core/colors.sh" ]]; then

    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/core/colors.sh"


else


    if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then


        COLOR_RESET=$'\033[0m'
        COLOR_BOLD=$'\033[1m'

        COLOR_RED=$'\033[31m'
        COLOR_GREEN=$'\033[32m'
        COLOR_YELLOW=$'\033[33m'
        COLOR_BLUE=$'\033[34m'
        COLOR_CYAN=$'\033[36m'


    else


        COLOR_RESET=""
        COLOR_BOLD=""

        COLOR_RED=""
        COLOR_GREEN=""
        COLOR_YELLOW=""
        COLOR_BLUE=""
        COLOR_CYAN=""


    fi

fi



export COLOR_RESET
export COLOR_BOLD

export COLOR_RED
export COLOR_GREEN
export COLOR_YELLOW
export COLOR_BLUE
export COLOR_CYAN



#
# Главный баннер LSM
#

print_header()
{

cat <<EOF

${COLOR_CYAN}${COLOR_BOLD}
=====================================================================
   __     _____    __  __   (LSM) Lite Server Monitor
  / /    / ___/   /  \/  |   Lightweight System Monitoring & Alerting
 / /___  \___ \  / /\__/ |   Version: ${PROJECT_VERSION}
/_____/ /_____/ /_/    /_/   Linux Server Management Tools
=====================================================================
${COLOR_RESET}

EOF

}



#
# Алиас баннера
#

ui_banner()
{
    print_header
}



#
# Заголовок раздела
#

ui_section()
{

    local title="${1:-}"

    printf "\n%s---> %s%s\n" \
        "${COLOR_BOLD}" \
        "${title}" \
        "${COLOR_RESET}"

}



#
# Разделитель
#

ui_separator()
{

    printf "%s\n" \
        "---------------------------------------------------------------------"

}



#
# Информационное сообщение
#

ui_info()
{

    printf "[ INFO ] %s\n" \
        "${1:-}"

}



#
# Успешное состояние
#

ui_ok()
{

    printf "%b[ OK   ]%b %s\n" \
        "${COLOR_GREEN}" \
        "${COLOR_RESET}" \
        "${1:-}"

}



#
# Предупреждение
#

ui_warn()
{

    printf "%b[ WARN ]%b %s\n" \
        "${COLOR_YELLOW}" \
        "${COLOR_RESET}" \
        "${1:-}"

}



#
# Ошибка
#

ui_fail()
{

    printf "%b[ FAIL ]%b %s\n" \
        "${COLOR_RED}" \
        "${COLOR_RESET}" \
        "${1:-}"

}



#
# Статус неизвестен
#

ui_unknown()
{

    printf "[ ???? ] %s\n" \
        "${1:-}"

}



#
# Совместимость со старыми вызовами
#

print_section()
{
    ui_section "$@"
}
