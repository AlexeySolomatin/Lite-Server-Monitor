#!/usr/bin/env bash
#
# Lite Server Monitor (LSM)
# ANSI color definitions
#

# Disable colors if:
# - stdout is not a terminal
# - NO_COLOR environment variable is set
if [[ ! -t 1 || -n "${NO_COLOR:-}" ]]; then
    readonly COLOR_RESET=""
    readonly COLOR_RED=""
    readonly COLOR_GREEN=""
    readonly COLOR_YELLOW=""
    readonly COLOR_BLUE=""
    readonly COLOR_MAGENTA=""
    readonly COLOR_CYAN=""
    readonly COLOR_WHITE=""
    readonly COLOR_BOLD=""
else
    readonly COLOR_RESET="\033[0m"
    readonly COLOR_BOLD="\033[1m"

    readonly COLOR_RED="\033[31m"
    readonly COLOR_GREEN="\033[32m"
    readonly COLOR_YELLOW="\033[33m"
    readonly COLOR_BLUE="\033[34m"
    readonly COLOR_MAGENTA="\033[35m"
    readonly COLOR_CYAN="\033[36m"
    readonly COLOR_WHITE="\033[37m"
fi
