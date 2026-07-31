#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Стартовый загрузчик (Bootstrap Installer)
# -----------------------------------------------------------------------------

set -Eeuo pipefail


readonly REPOSITORY_URL="https://github.com/AlexeySolomatin/Lite-Server-Monitor.git"
readonly ARCHIVE_URL="https://github.com/AlexeySolomatin/Lite-Server-Monitor/archive/refs/heads/main.tar.gz"


TEMP_DIR="$(mktemp -d)"
readonly TEMP_DIR

readonly SOURCE_DIR="${TEMP_DIR}/Lite-Server-Monitor"

#
# Определение цветов (только если вывод идет в интерактивный терминал)
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
# Минимальное bootstrap-логирование
#

bootstrap_log_info()
{
    local ts

    ts="$(_timestamp)"
    
    printf "${COLOR_GREEN}${ts} [ИНФО  ] [BOOTSTRAP]${COLOR_RESET} %s\n" "$*"
}


bootstrap_log_error()
{
    local ts

    ts="$(_timestamp)"
    
    printf "${COLOR_RED}${ts} [ОШИБКА] [BOOTSTRAP]${COLOR_RESET} %s\n" "$*" >&2
}



cleanup()
{
    rm -rf "${TEMP_DIR}"
}


trap cleanup EXIT



printf "\n"
printf "Стартовый загрузчик Lite Server Monitor\n"
printf "\n"



#
# Проверка прав root
#

if [[ "${EUID}" -ne 0 ]]; then

    bootstrap_log_error "Пожалуйста, запустите установку от имени root (используйте sudo)."

    exit 1

fi



#
# Загрузка исходных файлов
#

bootstrap_log_info "Загрузка Lite Server Monitor..."



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


    bootstrap_log_error "Утилиты git и curl не найдены. Пожалуйста, установите одну из них и повторите попытку."

    exit 1


fi



#
# Подготовка прав доступа
#

bootstrap_log_info "Подготовка файлов установщика..."

chmod -R +x "${SOURCE_DIR}"



#
# Пауза перед передачей управления
#

bootstrap_log_info "Исходные файлы успешно загружены."

# Проверяем, доступен ли управляющий терминал /dev/tty
if [[ -c /dev/tty ]]; then
    printf "\nНажмите [Enter] для запуска основного инсталлятора..."
    # Читаем нажатие клавиши напрямую из физического терминала пользователя,
    # игнорируя перенаправление stdin от curl/wget
    read -r _ < /dev/tty
else
    # Если терминала нет вообще (например, запуск из cron или CI/CD)
    sleep 3
fi



#
# Запуск основного установщика
#

printf "\n"

bootstrap_log_info "Запуск основного мастера установки..."

printf "\n"



#
# ВАЖНО:
# Вызов через bash (вместо exec) необходим для корректного срабатывания trap cleanup
#

bash "${SOURCE_DIR}/installer/install.sh" "$@"
