#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Команда вывода версии
#
# Путь:
#   commands/version.sh
#
# Назначение:
#   Отображение версии установленной копии LSM.
#
# ==============================================================================

set -Eeuo pipefail

LSM_ROOT="${LSM_ROOT:-/opt/lsm}"

# Если библиотека уже загружена, возьмем PROJECT_VERSION
if [[ -z "${PROJECT_VERSION:-}" && -f "${LSM_ROOT}/lib/core/common.sh" ]]; then
    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/core/common.sh"
fi

VERSION_FILE="${LSM_ROOT}/VERSION"

if [[ -n "${PROJECT_VERSION:-}" ]]; then
    echo "Lite Server Monitor v${PROJECT_VERSION}"
elif [[ -f "${VERSION_FILE}" ]]; then
    echo "Lite Server Monitor v$(tr -d '\r\n' < "${VERSION_FILE}")"
else
    echo "Lite Server Monitor (разрабатываемая версия)"
fi
