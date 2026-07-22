#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Bootstrap Installer
# -----------------------------------------------------------------------------

set -Eeuo pipefail

readonly REPOSITORY_URL="https://github.com/AlexeySolomatin/Lite-Server-Monitor.git"

TEMP_DIR="$(mktemp -d)"
readonly TEMP_DIR
readonly SOURCE_DIR="${TEMP_DIR}/Lite-Server-Monitor"

cleanup() {
    rm -rf "${TEMP_DIR}"
}

trap cleanup EXIT

echo
echo "Lite Server Monitor Bootstrap"
echo

#
# Root privileges
#

if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: Please run as root."
    exit 1
fi

#
# Install git if required
#

if ! command -v git >/dev/null 2>&1; then
    echo "Installing git..."

    apt-get update
    apt-get install -y git
fi

echo
echo "Downloading Lite Server Monitor..."
echo

git clone "${REPOSITORY_URL}" "${SOURCE_DIR}"

echo
echo "Starting installer..."
echo

exec "${SOURCE_DIR}/installer/install.sh"
