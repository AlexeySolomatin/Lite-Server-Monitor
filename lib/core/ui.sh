#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Библиотека пользовательского интерфейса и форматирования терминала
#
# Путь:
#   lib/core/ui.sh
#
# Назначение:
#   Общие функции вывода для установщика и CLI:
#
#   - отображение баннера LSM;
#   - вывод заголовков разделов;
#   - управление цветами терминала;
#   - подготовка базовых функций UI.
#
# Используется:
#   installer/wizard.sh
#   installer/screens/*.sh
#   CLI-команды LSM
#
# Требования:
#   Bash 4+
#
# Совместимость:
#   - цвет отключается при выводе не в TTY;
#   - поддерживается переменная NO_COLOR;
#   - пригодно для CI/CD и автоматических запусков.
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
# Используется только если LSM_ROOT еще не установлен.
#

LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"



#
# Версия проекта
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
# Подключение цветов
#
# Если colors.sh уже загружен —
# используются существующие значения.
#
# Если нет — определяются локально.
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
        COLOR_MAGENTA=$'\033[35m'
        COLOR_CYAN=$'\033[36m'
        COLOR_WHITE=$'\033[37m'


    else


        COLOR_RESET=""
        COLOR_BOLD=""

        COLOR_RED=""
        COLOR_GREEN=""
        COLOR_YELLOW=""
        COLOR_BLUE=""
        COLOR_MAGENTA=""
        COLOR_CYAN=""
        COLOR_WHITE=""


    fi


fi



export COLOR_RESET
export COLOR_BOLD

export COLOR_RED
export COLOR_GREEN
export COLOR_YELLOW
export COLOR_BLUE
export COLOR_MAGENTA
export COLOR_CYAN
export COLOR_WHITE



#
# Верхний заголовок LSM
#

print_header()
{

    cat <<EOF

${COLOR_CYAN}${COLOR_BOLD}=====================================================================
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
# Используется в разных частях проекта.
#

ui_banner()
{

    print_header

}



#
# Вывод заголовка раздела
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
# Совместимость со старыми вызовами
#

print_section()
{

    ui_section "$@"

}
