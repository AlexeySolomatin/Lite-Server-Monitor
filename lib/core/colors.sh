#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Библиотека ANSI-цветов для консольного вывода
#
# Путь:
#   lib/core/colors.sh
#
# Назначение:
#   Централизованное определение цветов консольного интерфейса LSM.
#
# Основной API:
#
#   COLOR_RESET
#   COLOR_BOLD
#   COLOR_RED
#   COLOR_GREEN
#   COLOR_YELLOW
#   COLOR_BLUE
#   COLOR_MAGENTA
#   COLOR_CYAN
#   COLOR_WHITE
#
# Совместимость:
#
#   Существующие installer screens используют имена CLR_*:
#
#   CLR_RESET
#   CLR_BOLD
#   CLR_RED
#   CLR_GREEN
#   CLR_YELLOW
#   CLR_CYAN
#
#   CLR_* являются compatibility aliases к COLOR_*.
#
# Поведение:
#
#   - если stdout не является TTY — цвета отключаются;
#   - если установлена NO_COLOR — цвета отключаются;
#   - иначе используются ANSI-коды.
#
# ==============================================================================


#
# Защита от повторного подключения
#

[[ -n "${LSM_COLORS_LOADED:-}" ]] && return 0

LSM_COLORS_LOADED=1



#
# Определение цветового режима
#
# Цвета отключаются:
#
#   1. если stdout не является TTY;
#   2. если установлена NO_COLOR.
#

if [[ ! -t 1 || -n "${NO_COLOR:-}" ]]; then


    #
    # Цвета отключены.
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


else


    #
    # ANSI-коды.
    #

    COLOR_RESET=$'\033[0m'
    COLOR_BOLD=$'\033[1m'

    COLOR_RED=$'\033[31m'
    COLOR_GREEN=$'\033[32m'
    COLOR_YELLOW=$'\033[33m'
    COLOR_BLUE=$'\033[34m'
    COLOR_MAGENTA=$'\033[35m'
    COLOR_CYAN=$'\033[36m'
    COLOR_WHITE=$'\033[37m'


fi



#
# ==============================================================================
# Compatibility API
# ==============================================================================
#
# Старые installer screens используют CLR_*.
#
# Не меняем существующие screens и не дублируем ANSI-коды.
#
# CLR_* всегда получают значение соответствующего COLOR_*.
# ==============================================================================

CLR_RESET="${COLOR_RESET}"
CLR_BOLD="${COLOR_BOLD}"

CLR_RED="${COLOR_RED}"
CLR_GREEN="${COLOR_GREEN}"
CLR_YELLOW="${COLOR_YELLOW}"
CLR_CYAN="${COLOR_CYAN}"



#
# Экспорт основного API
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



#
# Экспорт compatibility API
#

export CLR_RESET
export CLR_BOLD

export CLR_RED
export CLR_GREEN
export CLR_YELLOW
export CLR_CYAN
