#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# CLI Command: Uninstall Wrapper
# -----------------------------------------------------------------------------

set -Eeuo pipefail

LSM_ROOT="${LSM_ROOT:-/opt/lsm}"
exec bash "${LSM_ROOT}/installer/uninstall.sh" "$@"
