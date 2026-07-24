#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Главный контроллер TUI интерфейса
# Путь: lib/tui/tui.sh
# ==============================================================================

set -Eeuo pipefail

[[ -n "${LSM_TUI_LOADED:-}" ]] && return 0
readonly LSM_TUI_LOADED=1

#
# Root
#

export LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

#
# Core
#

source "${LSM_ROOT}/lib/core/common.sh"
source "${LSM_ROOT}/lib/core/colors.sh"
source "${LSM_ROOT}/lib/core/logging.sh"
source "${LSM_ROOT}/lib/core/ui.sh"

#
# Installer API
#

source "${LSM_ROOT}/lib/installer/module_loader.sh"
source "${LSM_ROOT}/lib/installer/module_validator.sh"
source "${LSM_ROOT}/lib/installer/registry.sh"
source "${LSM_ROOT}/lib/installer/modules.sh"

#
# Paths
#

readonly LSM_TUI_DIR="${LSM_ROOT}/lib/tui"

#
# Safe source
#

load_tui_file()
{
    local file="$1"

    if [[ ! -f "${file}" ]]; then
        log_error "Файл TUI не найден: ${file}"
        return 1
    fi

    # shellcheck source=/dev/null
    source "${file}"
}

#
# API check
#

tui_check_dependencies()
{
    local required_functions=(
        registry_load_default
        module_loader_init
        module_loader_list
        module_validate_all
        modules_install
        modules_remove
    )

    local func

    for func in "${required_functions[@]}"; do
        if ! declare -f "${func}" >/dev/null 2>&1; then
            log_error "Отсутствует API TUI: ${func}"
            return 1
        fi
    done

    return 0
}

#
# Load screen
#

load_tui_screen()
{
    local screen="$1"

    load_tui_file \
        "${LSM_TUI_DIR}/screens/${screen}.sh"
}

#
# Load components
#

load_tui_components()
{
    local components=(
        core.sh
        menu.sh
    )

    local screens=(
        main
        modules
        install
        config
        report
        doctor
    )

    local component
    local screen

    for component in "${components[@]}"; do
        load_tui_file \
            "${LSM_TUI_DIR}/${component}" || return 1
    done

    for screen in "${screens[@]}"; do
        load_tui_screen "${screen}" || return 1
    done

    return 0
}

#
# Init
#

tui_init()
{
    if ! command -v dialog >/dev/null 2>&1; then
        log_error "Не установлен пакет dialog."
        log_info "Установите: apt install dialog"
        return 1
    fi

    tui_check_dependencies || return 1

    registry_load_default || return 1
    module_loader_init || return 1

    return 0
}

#
# Start
#

tui_start()
{
    tui_init || {
        log_error "Ошибка инициализации TUI"
        exit 1
    }

    load_tui_components || {
        log_error "Ошибка загрузки компонентов TUI"
        exit 1
    }

    clear

    if ! declare -f screen_main >/dev/null 2>&1; then
        log_error "Главный экран screen_main не найден"
        exit 1
    fi

    screen_main
}

#
# Standalone
#

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    tui_start
fi
