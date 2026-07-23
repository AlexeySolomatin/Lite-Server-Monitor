#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Скрипт удаления модуля мониторинга Docker
# Путь: modules/docker/uninstall.sh
# ==============================================================================

set -Eeuo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LSM_ROOT="${LSM_ROOT:-/opt/lsm}"

# Подключение базовых библиотек
if [[ -f "${LSM_ROOT}/lib/core/common.sh" ]]; then
    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/core/common.sh"
fi

if [[ -f "${LSM_ROOT}/lib/core/ui.sh" ]]; then
    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/core/ui.sh"
fi

if [[ -f "${LSM_ROOT}/lib/installer/deploy.sh" ]]; then
    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/installer/deploy.sh"
fi

if [[ -f "${LSM_ROOT}/lib/installer/services.sh" ]]; then
    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/installer/services.sh"
fi

if declare -f log_info >/dev/null 2>&1; then
    log_info "UNINSTALL" "Удаление модуля мониторинга Docker..."
else
    echo "Удаление модуля мониторинга Docker..."
fi

# 1. Остановка и отключение служб systemd
if command -v systemctl >/dev/null 2>&1; then
    if declare -f services_stop_and_disable >/dev/null 2>&1; then
        services_stop_and_disable "lsm-docker.timer" || true
        services_stop_and_disable "lsm-docker.service" || true
    else
        systemctl stop lsm-docker.timer lsm-docker.service 2>/dev/null || true
        systemctl disable lsm-docker.timer lsm-docker.service 2>/dev/null || true
    fi
fi

# 2. Удаление юнитов Systemd
if declare -f deploy_remove_file >/dev/null 2>&1; then
    deploy_remove_file "/etc/systemd/system/lsm-docker.service"
    deploy_remove_file "/etc/systemd/system/lsm-docker.timer"
else
    rm -f "/etc/systemd/system/lsm-docker.service"
    rm -f "/etc/systemd/system/lsm-docker.timer"
fi

# Перезагрузка конфигурации systemd
if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload || true
fi

# 3. Удаление конфигурационного файла модуля
if declare -f deploy_remove_file >/dev/null 2>&1; then
    deploy_remove_file "/etc/lsm/modules/docker.conf"
else
    rm -f "/etc/lsm/modules/docker.conf"
fi

# 4. Удаление рабочей директории модуля
if declare -f deploy_remove_directory >/dev/null 2>&1; then
    deploy_remove_directory "${LSM_ROOT}/modules/docker"
else
    rm -rf "${LSM_ROOT}/modules/docker"
fi

if declare -f log_success >/dev/null 2>&1; then
    log_success "UNINSTALL" "Модуль мониторинга Docker успешно удалён."
else
    echo "Модуль мониторинга Docker успешно удалён."
fi
