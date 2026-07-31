#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Wizard Common Helper Functions
# -----------------------------------------------------------------------------

set -Eeuo pipefail

# ANSI Цвета для оформления Wizard
CLR_RESET="\e[0m"
CLR_BOLD="\e[1m"
CLR_CYAN="\e[36m"
CLR_GREEN="\e[32m"
CLR_YELLOW="\e[33m"
CLR_RED="\e[31m"

# Инициализация TTY для корректного интерактивного ввода (например, при запуске через curl | bash)
wizard_init_tty() {
    if [[ ! -t 0 ]] && [[ -c /dev/tty ]]; then
        exec < /dev/tty
    fi
}

# Шапка мастера установки
wizard_header() {
    clear
    echo -e "${CLR_CYAN}${CLR_BOLD}===============================================================${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}                Lite Server Monitor Installation               ${CLR_RESET}"
    echo -e "${CLR_CYAN}${CLR_BOLD}===============================================================${CLR_RESET}"
    echo
}

# Пауза до нажатия Enter
wizard_pause() {
    echo
    read -rp "Нажмите Enter для продолжения..." _dummy
}

# Интерактивный да/нет диалог с поддержкой дефолтного ответа
# Использование: wizard_yes_no "Текст вопроса" [y|n]
wizard_yes_no() {
    local prompt="$1"
    local default_opt="${2:-y}"
    local hint="[y/N]"

    if [[ "${default_opt}" =~ ^[yY]$ ]]; then
        hint="[Y/n]"
    fi

    while true; do
        read -rp "$(echo -e "${CLR_BOLD}${prompt}${CLR_RESET} ${hint}: ")" answer
        answer="${answer:-${default_opt}}"

        case "${answer}" in
            y|Y)
                return 0
                ;;
            n|N)
                return 1
                ;;
            *)
                echo -e "${CLR_RED}Пожалуйста, введите 'y' (да) или 'n' (нет).${CLR_RESET}"
                ;;
        esac
    done
}

# Запрос текстового значения с поддержкой значением по умолчанию
# Использование: wizard_input "Подсказка" "переменная_результата" ["дефолтное_значение"]
wizard_input() {
    local prompt="$1"
    local var_name="$2"
    local default_val="${3:-}"
    local user_val=""

    if [[ -n "${default_val}" ]]; then
        read -rp "$(echo -e "${CLR_BOLD}${prompt}${CLR_RESET} [${CLR_YELLOW}${default_val}${CLR_RESET}]: ")" user_val
        eval "${var_name}=\"${user_val:-${default_val}}\""
    else
        while [[ -z "${user_val}" ]]; do
            read -rp "$(echo -e "${CLR_BOLD}${prompt}${CLR_RESET}: ")" user_val
        done
        eval "${var_name}=\"${user_val}\""
    fi
}

# Скрытый ввод секретов (токены, пароли)
# Использование: wizard_mask_input "Подсказка" "переменная_результата"
wizard_mask_input() {
    local prompt="$1"
    local var_name="$2"
    local secret_val=""

    while [[ -z "${secret_val}" ]]; do
        read -rsp "$(echo -e "${CLR_BOLD}${prompt}${CLR_RESET}: ")" secret_val
        echo
    done

    eval "${var_name}=\"${secret_val}\""
}
