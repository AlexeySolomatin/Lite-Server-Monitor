#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# CLI Command: Install Wrapper
# -----------------------------------------------------------------------------

set -Eeuo pipefail


if [[ -z "${LSM_ROOT:-}" ]]; then

    LSM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fi


export LSM_ROOT


INSTALLER="${LSM_ROOT}/installer/install.sh"


if [[ ! -f "${INSTALLER}" ]]; then

    printf "ERROR: installer not found: %s\n" "${INSTALLER}" >&2

    exit 1

fi


exec bash "${INSTALLER}" "$@"
