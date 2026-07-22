#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Core UI & Terminal Formatting Helpers
# -----------------------------------------------------------------------------

set -Eeuo pipefail

# Определение цветов (если терминал поддерживает ANSI)
if [[ -t 1 ]]; then
    COLOR_RESET="\033[0m"
    COLOR_BOLD="\033[1m"
    COLOR_RED="\033[0;31m"
    COLOR_GREEN="\033[0;32m"
    COLOR_YELLOW="\033[0;33m"
    COLOR_BLUE="\033[0;34m"
    COLOR_CYAN="\033[0;36m"
else
    COLOR_RESET=""
    COLOR_BOLD=""
    COLOR_RED=""
    COLOR_GREEN=""
    COLOR_YELLOW=""
    COLOR_BLUE=""
    COLOR_CYAN=""
fi

# Вывод баннера проекта (устраняет ошибку ui_banner)
ui_banner() {
    print_header
}

print_header() {
    cat << EOF

${COLOR_CYAN}${COLOR_BOLD}=====================================================================${COLOR_RESET}
${COLOR_CYAN}${COLOR_BOLD}   __    ____  __  __   (LSM) Lite Server Monitor                    ${COLOR_RESET}
${COLOR_CYAN}${COLOR_BOLD}  / /   / __/ /  \/  |  Lightweight System Monitoring & Alerting     ${COLOR_RESET}
${COLOR_CYAN}${COLOR_BOLD} / /___ \__ \ / /\_/ |  Version: ${PROJECT_VERSION:-1.0.0}                    ${COLOR_RESET}
${COLOR_CYAN}${COLOR_BOLD}/_____//____//_/  /_/   Linux Server Management Tools                ${COLOR_RESET}
${COLOR_CYAN}${COLOR_BOLD}=====================================================================${COLOR_RESET}

EOF
}

# Визуальное разделение блоков
ui_section() {
    local title="$1"
    echo -e "\n${COLOR_BOLD}---> ${title}${COLOR_RESET}"
}

# Форматирование сообщений с иконками
log_info() {
    echo -e "[${COLOR_BLUE}INFO${COLOR_RESET}] $1"
}

log_success() {
    echo -e "[${COLOR_GREEN} OK ${COLOR_RESET}] $1"
}

log_warn() {
    echo -e "[${COLOR_YELLOW}WARN${COLOR_RESET}] $1" >&2
}

log_error() {
    echo -e "[${COLOR_RED}FAIL${COLOR_RESET}] $1" >&2
}

log_debug() {
    if [[ "${LSM_DEBUG:-0}" == "1" ]]; then
        echo -e "[${COLOR_CYAN}DEBUG${COLOR_RESET}] $1"
    fi
}
