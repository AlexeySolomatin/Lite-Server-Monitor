#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Стартовый загрузчик (Bootstrap Installer)
# -----------------------------------------------------------------------------

set -Eeuo pipefail


readonly REPOSITORY_URL="https://github.com/AlexeySolomatin/Lite-Server-Monitor.git"
readonly ARCHIVE_URL="https://github.com/AlexeySolomatin/Lite-Server-Monitor/archive/refs/heads/main.tar.gz"


TEMP_DIR="$(mktemp -d /tmp/lsm-bootstrap.XXXXXX)"
readonly TEMP_DIR

readonly SOURCE_DIR="${TEMP_DIR}/Lite-Server-Monitor"



#
# Цвета
#

if [[ -t 1 ]]; then

    readonly COLOR_RESET="\033[0m"
    readonly COLOR_GREEN="\033[1;32m"
    readonly COLOR_RED="\033[1;31m"

else

    readonly COLOR_RESET=""
    readonly COLOR_GREEN=""
    readonly COLOR_RED=""

fi



#
# Время
#

_timestamp()
{
    date '+%Y-%m-%d %H:%M:%S'
}



#
# Bootstrap logging
#

bootstrap_log_info()
{
    local ts

    ts="$(_timestamp)"

    printf "%b%s [ИНФО  ] [BOOTSTRAP]%b %s\n" \
        "${COLOR_GREEN}" \
        "${ts}" \
        "${COLOR_RESET}" \
        "$*"
}



bootstrap_log_error()
{
    local ts

    ts="$(_timestamp)"

    printf "%b%s [ОШИБКА] [BOOTSTRAP]%b %s\n" \
        "${COLOR_RED}" \
        "${ts}" \
        "${COLOR_RESET}" \
        "$*" >&2
}



#
# Cleanup
#

cleanup()
{
    rm -rf "${TEMP_DIR}"
}


trap cleanup EXIT INT TERM



printf "\n"
printf "Lite Server Monitor Bootstrap Installer\n"
printf "\n"



#
# Root check
#

if [[ "${EUID}" -ne 0 ]]; then

    bootstrap_log_error \
        "Пожалуйста, запустите установку от имени root (sudo)."

    exit 1

fi



#
# Dependency check
#

if ! command -v git >/dev/null 2>&1 &&
   ! command -v curl >/dev/null 2>&1
then

    bootstrap_log_error \
        "Не найден git или curl."

    exit 1

fi



if ! command -v tar >/dev/null 2>&1; then

    bootstrap_log_error \
        "Не найден tar."

    exit 1

fi



#
# Download sources
#

bootstrap_log_info \
    "Загрузка Lite Server Monitor..."



if command -v git >/dev/null 2>&1; then


    if ! git clone \
        --depth 1 \
        "${REPOSITORY_URL}" \
        "${SOURCE_DIR}"
    then

        bootstrap_log_error \
            "Не удалось загрузить репозиторий Lite Server Monitor."

        exit 1

    fi



elif command -v curl >/dev/null 2>&1; then


    mkdir -p "${SOURCE_DIR}"


    if ! curl -fsSL "${ARCHIVE_URL}" \
        | tar -xz \
            -C "${SOURCE_DIR}" \
            --strip-components=1
    then

        bootstrap_log_error \
            "Не удалось загрузить архив Lite Server Monitor."

        exit 1

    fi


fi



#
# Validate source
#

if [[ ! -f "${SOURCE_DIR}/installer/install.sh" ]]; then

    bootstrap_log_error \
        "Повреждён пакет LSM: installer/install.sh отсутствует."

    exit 1

fi



#
# Prepare permissions
#

bootstrap_log_info \
    "Подготовка файлов установщика..."



find "${SOURCE_DIR}" \
    -type f \
    -name "*.sh" \
    -exec chmod +x {} \;



#
# Start installer
#

bootstrap_log_info \
    "Исходные файлы успешно загружены."



printf "\n"



bootstrap_log_info \
    "Запуск installer/install.sh..."



printf "\n"



#
# Вызов через bash сохраняет trap cleanup
#

bash "${SOURCE_DIR}/installer/install.sh" "$@"
