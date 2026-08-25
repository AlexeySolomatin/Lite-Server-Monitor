#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Обёртка запуска удаления
#
# Путь:
#   commands/uninstall.sh
#
# Назначение:
#   Запуск главного скрипта удаления installer/uninstall.sh.
#
# ==============================================================================

set -Eeuo pipefail

LSM_ROOT="${LSM_ROOT:-/opt/lsm}"
exec bash "${LSM_ROOT}/installer/uninstall.sh" "$@"
