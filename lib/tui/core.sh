#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Ядро TUI интерфейса
# Путь: lib/tui/core.sh
# ==============================================================================


set -Eeuo pipefail


[[ -n "${LSM_TUI_CORE_LOADED:-}" ]] && return 0
readonly LSM_TUI_CORE_LOADED=1



#
# Проверка интерактивного терминала
#

tui_check_terminal()
{

    if [[ ! -t 0 ]]; then

        log_error "TUI требует интерактивный терминал."

        return 1

    fi

}



#
# Очистка экрана
#

tui_clear()
{

    clear

}



#
# Проверка dialog
#

tui_check_dialog()
{

    if ! command -v dialog >/dev/null 2>&1; then

        log_error "Не найден пакет dialog."

        log_info "Установите: apt install dialog"

        return 1

    fi

}



#
# Информационное окно
#

tui_message()
{

    local title="${1:-LSM}"
    local message="${2:-}"


    dialog \
        --clear \
        --title "${title}" \
        --msgbox "${message}" \
        12 60

}



#
# Подтверждение действия
#

tui_confirm()
{

    local message="${1:-Продолжить?}"


    dialog \
        --clear \
        --yesno "${message}" \
        10 50

}



#
# Окно ошибки
#

tui_error()
{

    tui_message \
        "Ошибка" \
        "$1"

}



#
# Успешное выполнение
#

tui_success()
{

    tui_message \
        "Успешно" \
        "$1"

}



#
# Предупреждение
#

tui_warning()
{

    tui_message \
        "Внимание" \
        "$1"

}



#
# Пауза
#

tui_pause()
{

    dialog \
        --clear \
        --msgbox "Нажмите Enter для продолжения" \
        8 40

}
