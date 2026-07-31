#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Wizard Common Helper Functions
# Путь: installer/screens/common.sh
# -----------------------------------------------------------------------------

set -Eeuo pipefail

# Подключаем UI библиотеку (путь относительно wizard.sh)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../ui.sh"

# ANSI Цвета для Wizard (локально, если нужно что-то дополнительно)
CLR_RESET="\e[0m"
CLR_BOLD="\e[1m"
CLR_CYAN="\e[36m"
CLR_GREEN="\e[32m"
CLR_YELLOW="\e[33m"
CLR_RED="\e[31m"

# Если цвета уже отключены в ui.sh, обнуляем и эти тоже, чтобы не было рассинхрона
if [[ -z "${COLOR_RESET:-}" ]]; then
    CLR_RESET=""
    CLR_BOLD=""
    CLR_CYAN=""
    CLR_GREEN=""
    CLR_YELLOW=""
    CLR_RED=""
fi

# -----------------------------------------------------------------------------
# Инициализация TTY для корректного интерактивного ввода
# (например, при запуске через curl | bash)
# -----------------------------------------------------------------------------
wizard_init_tty() {
    if [[ ! -t 0 ]] && [[ -c /dev/tty ]]; then
        exec < /dev/tty
    fi
}

# -----------------------------------------------------------------------------
# Шапка мастера установки (теперь использует ui_banner из ui.sh)
# -----------------------------------------------------------------------------
wizard_header() {
    clear
    ui_banner
}

# -----------------------------------------------------------------------------
# Пауза до нажатия Enter
# -----------------------------------------------------------------------------
wizard_pause() {
    echo
    read -rp "Нажмите Enter для продолжения..." _dummy
}

# -----------------------------------------------------------------------------
# Интерактивный да/нет диалог с поддержкой дефолтного ответа
# Использование: wizard_yes_no "Текст вопроса" [y|n]
# -----------------------------------------------------------------------------
wizard_yes_no() {
    local prompt="$1"
    local default_opt="${2:-y}"
    local hint="[y/N]"

    if [[ "${default_opt}" =~ ^[yY]$ ]]; then
        hint="[Y/n]"
    fi

    while true; do
        read -rp "${CLR_BOLD}${prompt}${CLR_RESET} ${hint}: " answer
        answer="${answer:-${default_opt}}"

        case "${answer}" in
            y|Y) return 0 ;;
            n|N) return 1 ;;
            *)
                echo -e "${CLR_RED}Пожалуйста, введите 'y' (да) или 'n' (нет).${CLR_RESET}" >&2
                ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Запрос текстового значения с поддержкой значения по умолчанию
# Использование: wizard_input "Подсказка" "переменная_результата" ["дефолтное_значение"]
# -----------------------------------------------------------------------------
wizard_input() {
    local prompt="$1"
    local var_name="$2"
    local default_val="${3:-}"
    local user_val

    if [[ -n "${default_val}" ]]; then
        read -rp "${CLR_BOLD}${prompt}${CLR_RESET} [${CLR_YELLOW}${default_val}${CLR_RESET}]: " user_val
        user_val="${user_val:-${default_val}}"
    else
        while [[ -z "${user_val}" ]]; do
            read -rp "${CLR_BOLD}${prompt}${CLR_RESET}: " user_val
        done
    fi

    eval "${var_name}=\"${user_val}\""
}

# -----------------------------------------------------------------------------
# Скрытый ввод секретов (токены, пароли)
# Использование: wizard_mask_input "Подсказка" "переменная_результата"
# -----------------------------------------------------------------------------
wizard_mask_input() {
    local prompt="$1"
    local var_name="$2"
    local secret_val

    while [[ -z "${secret_val}" ]]; do
        read -rsp "${CLR_BOLD}${prompt}${CLR_RESET}: " secret_val
    done
    echo  # перевод строки после скрытого ввода

    eval "${var_name}=\"${secret_val}\""
}

# -----------------------------------------------------------------------------
# Обработка прерываний (Ctrl+C)
# -----------------------------------------------------------------------------
wizard_trap_init() {
    trap 'echo -e "\n${CLR_YELLOW}${CLR_BOLD}Установка прервана пользователем.${CLR_RESET}" >&2; exit 130' INT TERM
}
