#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Update Manager
# -----------------------------------------------------------------------------

set -Eeuo pipefail

LSM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly LSM_ROOT

main() {

    echo "Updating Lite Server Monitor..."
    echo

    git -C "${LSM_ROOT}" pull

    echo

    "${LSM_ROOT}/installer/install.sh"

}

main "$@"
