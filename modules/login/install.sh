#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Скрипт установки модуля контроля входов пользователей
# Путь: modules/login/install.sh
# ==============================================================================

set -Eeuo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LSM_ROOT="${LSM_ROOT:-/opt/lsm}"

# Подключение базовых библиотек и хелперов установки
if [[ -f "${LSM_ROOT}/lib/core/common.sh" ]]; then
    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/core/common.sh"
elif [[ -f "${MODULE_DIR}/../../lib/core/common.sh" ]]; then
    # shellcheck source=/dev/null
    source "${MODULE_DIR}/../../lib/core/common.sh"
fi

if [[ -f "${LSM_ROOT}/lib/core/ui.sh" ]]; then
    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/core/ui.sh"
elif [[ -f "${MODULE_DIR}/../../lib/core/ui.sh" ]]; then
    # shellcheck source=/dev/null
    source "${MODULE_DIR}/../../lib/core/ui.sh"
fi

if [[ -f "${LSM_ROOT}/lib/installer/deploy.sh" ]]; then
    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/installer/deploy.sh"
elif [[ -f "${MODULE_DIR}/../../lib/installer/deploy.sh" ]]; then
    # shellcheck source=/dev/null
    source "${MODULE_DIR}/../../lib/installer/deploy.sh"
fi

#
# Резервные функции журналирования на случай,
# если библиотеки ядра недоступны
#

if ! declare -F log_info >/dev/null 2>&1; then
    log_info() { printf '%s\n' "$*"; }
fi

if ! declare -F log_warn >/dev/null 2>&1; then
    log_warn() { printf '%s\n' "$*" >&2; }
fi

if ! declare -F log_error >/dev/null 2>&1; then
    log_error() { printf '%s\n' "$*" >&2; }
fi

if ! declare -F log_success >/dev/null 2>&1; then
    log_success() { printf '%s\n' "$*"; }
fi

log_info "LOGIN" "Установка модуля контроля входов пользователей..."

# 1. Директории
deploy_create_directory "${LSM_ROOT}/modules/login" "755" "root" "root"
deploy_create_directory "/etc/lsm/modules" "755" "root" "root"

# Примечание: исполняемый скрипт files/check_login.sh попадает в
# /opt/lsm/modules/login/files/ при копировании всего дерева проекта.
# Плоские копии check_*.sh в корень каталога модуля не создаются.

# 2. Systemd юниты
if [[ -f "${MODULE_DIR}/files/lsm-login.service" ]]; then
    deploy_install_file \
        "${MODULE_DIR}/files/lsm-login.service" \
        "/etc/systemd/system/lsm-login.service" \
        "644" "root" "root"
fi
if [[ -f "${MODULE_DIR}/files/lsm-login.timer" ]]; then
    deploy_install_file \
        "${MODULE_DIR}/files/lsm-login.timer" \
        "/etc/systemd/system/lsm-login.timer" \
        "644" "root" "root"
fi

# 3. Конфигурация (без перезаписи существующей)
if [[ -f "${MODULE_DIR}/templates/login.conf" ]]; then
    if [[ ! -f "/etc/lsm/modules/login.conf" ]]; then
        deploy_install_file \
            "${MODULE_DIR}/templates/login.conf" \
            "/etc/lsm/modules/login.conf" \
            "640" "root" "root"
    else
        log_warn "LOGIN" "Конфигурационный файл /etc/lsm/modules/login.conf уже существует, пропуск перезаписи."
    fi
fi

# 4. Активация таймера
if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload || true
    systemctl enable --now lsm-login.timer || true
fi

log_success "LOGIN" "Модуль контроля входов пользователей успешно установлен."
