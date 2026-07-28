#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Bootstrap Installer
# -----------------------------------------------------------------------------

set -Eeuo pipefail

readonly REPOSITORY_URL="https://github.com/AlexeySolomatin/Lite-Server-Monitor.git"
readonly ARCHIVE_URL="https://github.com/AlexeySolomatin/Lite-Server-Monitor/archive/refs/heads/main.tar.gz"

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
# Запуск основного установщика!!!
#

if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: Please run as root (use sudo)."
    exit 1
fi

#
# Download source files
#

echo "Downloading Lite Server Monitor..."

if command -v git >/dev/null 2>&1; then
    git clone --depth 1 "${REPOSITORY_URL}" "${SOURCE_DIR}" >/dev/null 2>&1
elif command -v curl >/dev/null 2>&1; then
    mkdir -p "${SOURCE_DIR}"
    curl -fsSL "${ARCHIVE_URL}" | tar -xz -C "${SOURCE_DIR}" --strip-components=1
else
    echo "ERROR: Neither 'git' nor 'curl' is installed. Please install one of them and try again."
    exit 1
fi

#
# Исправляем права доступа
#

chmod -R +x "${SOURCE_DIR}"

#
# Запуск основного установщм=ика
#

echo
echo "Starting installer..."
echo

# ВАЖНО: Вызываем через bash (без exec), чтобы сработал 'trap cleanup EXIT'
bash "${SOURCE_DIR}/installer/install.sh" "$@"
