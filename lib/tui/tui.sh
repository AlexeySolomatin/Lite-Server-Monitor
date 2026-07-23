#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Главный контроллер TUI интерфейса
# Путь: lib/tui/tui.sh
# ==============================================================================


set -Eeuo pipefail


#
# Защита от повторной загрузки
#

[[ -n "${LSM_TUI_LOADED:-}" ]] && return 0
readonly LSM_TUI_LOADED=1



#
# Определение корня проекта
#

LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

export LSM_ROOT



#
# Загрузка ядра
#

source "${LSM_ROOT}/lib/core/common.sh"
source "${LSM_ROOT}/lib/core/colors.sh"
source "${LSM_ROOT}/lib/core/logging.sh"
source "${LSM_ROOT}/lib/core/ui.sh"



#
# Загрузка installer API
#

source "${LSM_ROOT}/lib/installer/registry.sh"
source "${LSM_ROOT}/lib/installer/modules.sh"
source "${LSM_ROOT}/lib/installer/module_loader.sh"



#
# Загрузка TUI ядра
#

readonly LSM_TUI_DIR="${LSM_ROOT}/lib/tui"



if [[ -f "${LSM_TUI_DIR}/core.sh" ]]; then
    source "${LSM_TUI_DIR}/core.sh"
fi


if [[ -f "${LSM_TUI_DIR}/menu.sh" ]]; then
    source "${LSM_TUI_DIR}/menu.sh"
fi



#
# Загрузка экранов
#

load_tui_screen()
{
    local screen="$1"

    local file="${LSM_TUI_DIR}/screens/${screen}.sh"


    if [[ -f "${file}" ]]; then

        # shellcheck source=/dev/null
        source "${file}"

    else

        log_error "TUI экран не найден: ${file}"
        return 1

    fi
}



load_tui_screen "main"
load_tui_screen "modules"
load_tui_screen "install"
load_tui_screen "config"
load_tui_screen "report"
load_tui_screen "doctor"



#
# Инициализация TUI
#

tui_init()
{

    if ! command -v dialog >/dev/null 2>&1; then

        log_error "Не установлен пакет dialog."

        log_info "Установите: apt install dialog"

        return 1

    fi


    registry_load_default


    module_loader_init


}



#
# Запуск интерфейса
#

tui_start()
{

    tui_init


    clear


    screen_main


}



#
# Автозапуск при прямом вызове
#

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

    tui_start

fi
