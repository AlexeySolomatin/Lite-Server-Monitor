#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Обёртка запуска установки
#
# Путь:
#   commands/install.sh
#
# Назначение:
#   Запуск главного установщика installer/install.sh.
#
# ==============================================================================

set -Eeuo pipefail


if [[ -z "${LSM_ROOT:-}" ]]; then

    LSM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fi


export LSM_ROOT


INSTALLER="${LSM_ROOT}/installer/install.sh"


if [[ ! -f "${INSTALLER}" ]]; then

    printf "ОШИБКА: установщик не найден: %s\n" "${INSTALLER}" >&2

    exit 1

fi


exec bash "${INSTALLER}" "$@"
