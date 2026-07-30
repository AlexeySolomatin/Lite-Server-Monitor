#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Главный контроллер TUI-интерфейса
# Путь: lib/tui/tui.sh
# ==============================================================================

set -Eeuo pipefail

[[ -n "${LSM_TUI_LOADED:-}" ]] && return 0
readonly LSM_TUI_LOADED=1

#
# Корень репозитория / системы!
#

export LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

#
# Подключение библиотек ядра
#

source "${LSM_ROOT}/lib/core/common.sh"
source "${LSM_ROOT}/lib/core/colors.sh"
source "${LSM_ROOT}/lib/core/logging.sh"
source "${LSM_ROOT}/lib/core/ui.sh"

#
# API инсталлятора
#

source "${LSM_ROOT}/lib/installer/module_loader.sh"
source "${LSM_ROOT}/lib/installer/module_validator.sh"
source "${LSM_ROOT}/lib/installer/registry.sh"
source "${LSM_ROOT}/lib/installer/modules.sh"

#
# Пути к компонентам TUI
#

readonly LSM_TUI_DIR="${LSM_ROOT}/lib/tui"

#
# Безопасная загрузка файлов
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
# Проверка наличия необходимых функций API
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
            log_error "Отсутствует необходимый метод API TUI: ${func}"
            return 1
        fi
    done

    return 0
}

#
# Загрузка экранов
#

load_tui_screen()
{
    local screen="$1"

    load_tui_file \
        "${LSM_TUI_DIR}/screens/${screen}.sh"
}

#
# Загрузка визуальных компонентов
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
# Инициализация и проверка окружения TUI
#

tui_init()
{
    # Определение доступной утилиты отрисовки диалогов (dialog -> whiptail)
    if command -v dialog >/dev/null 2>&1; then
        export DIALOG_BIN="dialog"
    elif command -v whiptail >/dev/null 2>&1; then
        export DIALOG_BIN="whiptail"
    else
        log_error "Не найдена утилита для отрисовки TUI (dialog или whiptail)."
        log_info "Установите один из пакетов: apt install dialog (или whiptail)"
        return 1
    fi

    tui_check_dependencies || return 1

    registry_load_default || return 1
    module_loader_init || return 1

    return 0
}

#
# Запуск TUI интерфейса
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
# Автономный запуск
#

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    tui_start
fi
