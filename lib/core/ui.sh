#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Библиотека пользовательского интерфейса и форматирования терминала
#
# Путь:
#   lib/core/ui.sh
#
# Назначение:
#   Единый слой отображения информации пользователю.
#
# Возможности:
#
#   - баннер LSM;
#   - заголовки разделов;
#   - форматирование статусов;
#   - управление цветами;
#   - безопасная работа в CLI/cron/systemd.
#
# Важно:
#
#   ui.sh отвечает только за отображение.
#   Запись событий выполняет logging.sh.
#
# ==============================================================================


set -Eeuo pipefail



#
# Защита от повторной загрузки
#

[[ -n "${LSM_UI_LOADED:-}" ]] && return 0

readonly LSM_UI_LOADED=1



#
# Определение корня LSM
#

LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"



#
# Получение версии проекта
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
# Загрузка цветов
#

if [[ -f "${LSM_ROOT}/lib/core/colors.sh" ]]; then

    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/core/colors.sh"


fi



#
# Fallback цветов.
#
# Цвета отключаются:
#
# - если вывод не в терминал;
# - если установлен NO_COLOR.
#

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then


    : "${COLOR_RESET:=$'\033[0m'}"
    : "${COLOR_BOLD:=$'\033[1m'}"

    : "${COLOR_RED:=$'\033[31m'}"
    : "${COLOR_GREEN:=$'\033[32m'}"
    : "${COLOR_YELLOW:=$'\033[33m'}"
    : "${COLOR_BLUE:=$'\033[34m'}"
    : "${COLOR_MAGENTA:=$'\033[35m'}"
    : "${COLOR_CYAN:=$'\033[36m'}"


else


    COLOR_RESET=""
    COLOR_BOLD=""

    COLOR_RED=""
    COLOR_GREEN=""
    COLOR_YELLOW=""
    COLOR_BLUE=""
    COLOR_MAGENTA=""
    COLOR_CYAN=""


fi



export COLOR_RESET
export COLOR_BOLD

export COLOR_RED
export COLOR_GREEN
export COLOR_YELLOW
export COLOR_BLUE
export COLOR_MAGENTA
export COLOR_CYAN



#
# Вывод баннера LSM
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
        "============================================================"

}



#
# Универсальный вывод статуса
#

_ui_status()
{
    local label="$1"
    local color="$2"
    local message="$3"


    printf "%b[ %-7s ]%b %s\n" \
        "${color}" \
        "${label}" \
        "${COLOR_RESET}" \
        "${message}"
}



#
# Успешное состояние
#

ui_ok()
{
    _ui_status \
        "OK" \
        "${COLOR_GREEN}" \
        "${1:-}"
}



#
# Предупреждение
#

ui_warn()
{
    _ui_status \
        "WARN" \
        "${COLOR_YELLOW}" \
        "${1:-}"
}



#
# Ошибка проверки состояния
#

ui_fail()
{
    _ui_status \
        "FAIL" \
        "${COLOR_RED}" \
        "${1:-}"
}



#
# Ошибка выполнения
#

ui_error()
{
    _ui_status \
        "ERROR" \
        "${COLOR_RED}" \
        "${1:-}"
}



#
# Информационное сообщение
#

ui_info()
{
    _ui_status \
        "INFO" \
        "${COLOR_BLUE}" \
        "${1:-}"
}



#
# Отладочная информация
#

ui_debug()
{
    _ui_status \
        "DEBUG" \
        "${COLOR_MAGENTA}" \
        "${1:-}"
}



#
# Совместимость со старыми вызовами
#

print_section()
{
    ui_section "$@"
}
