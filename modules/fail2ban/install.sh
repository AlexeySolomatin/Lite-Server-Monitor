#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Скрипт установки модуля мониторинга Fail2Ban
# Путь: modules/fail2ban/install.sh
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

log_info "FAIL2BAN" "Установка модуля мониторинга Fail2Ban..."

# 1. Директории
deploy_create_directory "${LSM_ROOT}/modules/fail2ban" "755" "root" "root"
deploy_create_directory "/etc/lsm/modules" "755" "root" "root"

# Примечание: исполняемый скрипт files/check_fail2ban.sh попадает в
# /opt/lsm/modules/fail2ban/files/ при копировании всего дерева проекта.
# Плоские копии check_*.sh в корень каталога модуля не создаются.

# 2. Systemd юниты
if [[ -f "${MODULE_DIR}/files/lsm-fail2ban.service" ]]; then
    deploy_install_file \
        "${MODULE_DIR}/files/lsm-fail2ban.service" \
        "/etc/systemd/system/lsm-fail2ban.service" \
        "644" "root" "root"
fi
if [[ -f "${MODULE_DIR}/files/lsm-fail2ban.timer" ]]; then
    deploy_install_file \
        "${MODULE_DIR}/files/lsm-fail2ban.timer" \
        "/etc/systemd/system/lsm-fail2ban.timer" \
        "644" "root" "root"
fi

# 3. Конфигурация (без перезаписи существующей)
if [[ -f "${MODULE_DIR}/templates/fail2ban.conf" ]]; then
    if [[ ! -f "/etc/lsm/modules/fail2ban.conf" ]]; then
        deploy_install_file \
            "${MODULE_DIR}/templates/fail2ban.conf" \
            "/etc/lsm/modules/fail2ban.conf" \
            "640" "root" "root"
    else
        log_warn "FAIL2BAN" "Конфигурационный файл /etc/lsm/modules/fail2ban.conf уже существует, пропуск перезаписи."
    fi
fi

# 4. Активация таймера
if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload || true
    systemctl enable --now lsm-fail2ban.timer || true
fi

log_success "FAIL2BAN" "Модуль мониторинга Fail2Ban успешно установлен."
