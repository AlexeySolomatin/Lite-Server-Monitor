#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Запуск TUI
# Путь: commands/tui.sh
# ==============================================================================


set -Eeuo pipefail


LSM_ROOT="/opt/lsm"


source "${LSM_ROOT}/lib/core/common.sh"

source "${LSM_ROOT}/lib/tui/tui.sh"


tui_start
