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


exec bash \
    "${LSM_ROOT}/installer/install.sh" \
    "$@"
