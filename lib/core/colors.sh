#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Определение ANSI-цветов для консольного вывода
# Путь: lib/core/colors.sh
# ==============================================================================


# shellcheck disable=SC2034


#
# Защита от повторного подключения
#

[[ -n "${LSM_COLORS_LOADED:-}" ]] && return 0
LSM_COLORS_LOADED=1



#
# Определение цветов
#

if [[ ! -t 1 || -n "${NO_COLOR:-}" ]]; then

    COLOR_RESET=""
    COLOR_BOLD=""

    COLOR_RED=""
    COLOR_GREEN=""
    COLOR_YELLOW=""
    COLOR_BLUE=""
    COLOR_MAGENTA=""
    COLOR_CYAN=""
    COLOR_WHITE=""

else

    COLOR_RESET="\033[0m"
    COLOR_BOLD="\033[1m"

    COLOR_RED="\033[31m"
    COLOR_GREEN="\033[32m"
    COLOR_YELLOW="\033[33m"
    COLOR_BLUE="\033[34m"
    COLOR_MAGENTA="\033[35m"
    COLOR_CYAN="\033[36m"
    COLOR_WHITE="\033[37m"

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
