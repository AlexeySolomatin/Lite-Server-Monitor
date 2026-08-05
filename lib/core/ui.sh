#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Библиотека пользовательского интерфейса и форматирования терминала
#
# Путь:
#   lib/core/ui.sh
#
# Назначение:
#   Общие функции пользовательского интерфейса LSM:
#
#   - отображение баннера LSM;
#   - вывод заголовков разделов;
#   - единое терминальное оформление;
#   - использование централизованных ANSI-цветов;
#   - совместимость с CLI, installer и автоматическими запусками.
#
# Используется:
#   commands/*.sh
#   installer/wizard.sh
#   installer/screens/*.sh
#   другие CLI-компоненты LSM
#
# Требования:
#   Bash 4+
#
# Зависимости:
#   lib/core/colors.sh
#
# Совместимость:
#   - цвета отключаются при выводе не в TTY;
#   - поддерживается переменная NO_COLOR;
#   - ANSI-коды не определяются локально;
#   - пригодно для CI/CD и автоматических запусков.
#
# ==============================================================================


set -Eeuo pipefail



#
# Защита от повторной загрузки библиотеки.
#
# Так как библиотеки LSM подключаются через source,
# повторная загрузка не требуется.
#

[[ -n "${LSM_UI_LOADED:-}" ]] && return 0

readonly LSM_UI_LOADED=1



#
# Определение корня проекта.
#
# Используется только если LSM_ROOT еще не установлен.
#

LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

export LSM_ROOT



#
# Получение версии проекта.
#
# Версия берется из единственного источника:
#
#   VERSION
#
# Если VERSION отсутствует,
# используется значение "unknown".
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
# Подключение централизованной библиотеки цветов.
#
# Все ANSI-коды определяются только в:
#
#   lib/core/colors.sh
#
# ui.sh не должен самостоятельно определять COLOR_*.
#

if [[ -f "${LSM_ROOT}/lib/core/colors.sh" ]]; then

    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/core/colors.sh"

else

    #
    # Безопасный fallback.
    #
    # Это позволяет UI работать даже если colors.sh
    # временно отсутствует.
    #

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



#
# Экспорт цветовых переменных.
#
# Обычно они уже экспортируются colors.sh,
# но экспорт здесь гарантирует доступность переменных
# для дочерних компонентов, использующих UI.
#

export COLOR_RESET
export COLOR_BOLD

export COLOR_RED
export COLOR_GREEN
export COLOR_YELLOW
export COLOR_BLUE
export COLOR_MAGENTA
export COLOR_CYAN
export COLOR_WHITE



# ==============================================================================
# Баннер LSM
# ==============================================================================

#
# print_header
#
# Отображает основной баннер Lite Server Monitor.
#
# Баннер является исключительно элементом UI.
#
# Логирование состояния системы через эту функцию
# не выполняется.
#

print_header()
{

    printf '\n'

    printf '%s%s' \
        "${COLOR_CYAN}" \
        "${COLOR_BOLD}"

    printf '%s\n' \
        '====================================================================='

    printf '%s\n' \
        '   __     _____    __  __   (LSM) Lite Server Monitor'

    printf '%s\n' \
        '  / /    / ___/   /  \/  |   Lightweight System Monitoring & Alerting'

    printf ' / /___  \___ \  / /\__/ |   Version: %s\n' \
        "${PROJECT_VERSION}"

    printf '%s\n' \
        '/_____/ /_____/ /_/    /_/   Linux Server Management Tools'

    printf '%s\n' \
        '====================================================================='

    printf '%s' \
        "${COLOR_RESET}"

    printf '\n'

}



#
# ui_banner
#
# Основной публичный алиас баннера.
#
# Используется компонентами LSM, которым нужен именно UI API.
#

ui_banner()
{

    print_header

}



# ==============================================================================
# Заголовки разделов
# ==============================================================================

#
# ui_section
#
# Выводит заголовок отдельного раздела CLI.
#
# Пример:
#
#   ui_section "Диагностика системы"
#
# Результат:
#
#   ---> Диагностика системы
#
#

ui_section()
{

    local title="${1:-}"



    printf '\n%s---> %s%s\n' \
        "${COLOR_BOLD}" \
        "${title}" \
        "${COLOR_RESET}"

}



#
# print_section
#
# Обратная совместимость со старым API.
#
# Старый код может продолжать использовать:
#
#   print_section "..."
#
# Новый код должен использовать:
#
#   ui_section "..."
#

print_section()
{

    ui_section "$@"

}
