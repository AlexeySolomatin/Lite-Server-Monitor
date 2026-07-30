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



#
# Минимальное bootstrap логирование
#

bootstrap_log_info()
{
    printf "[INFO] %s\n" "$*"
}


bootstrap_log_error()
{
    printf "[ERROR] %s\n" "$*" >&2
}



cleanup()
{
    rm -rf "${TEMP_DIR}"
}


trap cleanup EXIT



printf "\n"
printf "Lite Server Monitor Bootstrap\n"
printf "\n"



#
# Проверка root
#

if [[ "${EUID}" -ne 0 ]]; then

    bootstrap_log_error "Please run as root (use sudo)."

    exit 1

fi



#
# Загрузка исходников
#

bootstrap_log_info "Downloading Lite Server Monitor..."



if command -v git >/dev/null 2>&1; then


    git clone \
        --depth 1 \
        "${REPOSITORY_URL}" \
        "${SOURCE_DIR}" \
        >/dev/null 2>&1



elif command -v curl >/dev/null 2>&1; then


    mkdir -p "${SOURCE_DIR}"


    curl -fsSL "${ARCHIVE_URL}" \
        | tar -xz \
            -C "${SOURCE_DIR}" \
            --strip-components=1



else


    bootstrap_log_error "Neither git nor curl is installed. Please install one of them and try again."

    exit 1


fi



#
# Исправление прав
#

bootstrap_log_info "Preparing installer files..."

chmod -R +x "${SOURCE_DIR}"



#
# Запуск основного установщика
#

printf "\n"

bootstrap_log_info "Starting installer..."

printf "\n"



#
# ВАЖНО:
# bash вместо exec нужен для корректной работы cleanup trap
#

bash "${SOURCE_DIR}/installer/install.sh" "$@"
