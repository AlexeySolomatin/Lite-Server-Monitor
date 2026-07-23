#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Скрипт установки модуля мониторинга Docker
# Путь: modules/docker/install.sh
# ==============================================================================

set -Eeuo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LSM_ROOT="${LSM_ROOT:-/opt/lsm}"

# Подключение базовых библиотек и хелперов установки
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

if declare -f log_info >/dev/null 2>&1; then
    log_info "INSTALL" "Установка модуля мониторинга Docker..."
else
    echo "Установка модуля мониторинга Docker..."
fi

# 1. Создание целевых директорий
deploy_create_directory "${LSM_ROOT}/modules/docker" "755" "root" "root"
deploy_create_directory "/etc/lsm/modules" "755" "root" "root"

# 2. Установка исполняемого скрипта проверки
if [[ -f "${MODULE_DIR}/files/check_docker.sh" ]]; then
    deploy_install_file \
        "${MODULE_DIR}/files/check_docker.sh" \
        "${LSM_ROOT}/modules/docker/check_docker.sh" \
        "755" "root" "root"
fi

# 3. Установка юнитов Systemd
if [[ -f "${MODULE_DIR}/files/lsm-docker.service" ]]; then
    deploy_install_file \
        "${MODULE_DIR}/files/lsm-docker.service" \
        "/etc/systemd/system/lsm-docker.service" \
        "644" "root" "root"
fi

if [[ -f "${MODULE_DIR}/files/lsm-docker.timer" ]]; then
    deploy_install_file \
        "${MODULE_DIR}/files/lsm-docker.timer" \
        "/etc/systemd/system/lsm-docker.timer" \
        "644" "root" "root"
fi

# 4. Установка конфигурационного файла (без перезаписи существующего)
if [[ -f "${MODULE_DIR}/templates/docker.conf" ]]; then
    if [[ ! -f "/etc/lsm/modules/docker.conf" ]]; then
        deploy_install_file \
            "${MODULE_DIR}/templates/docker.conf" \
            "/etc/lsm/modules/docker.conf" \
            "640" "root" "root"
    else
        if declare -f log_warn >/dev/null 2>&1; then
            log_warn "INSTALL" "Конфигурационный файл /etc/lsm/modules/docker.conf уже существует, пропуск перезаписи."
        else
            echo "Предупреждение: Конфигурационный файл /etc/lsm/modules/docker.conf уже существует, пропуск перезаписи." >&2
        fi
    fi
fi

# 5. Перезагрузка конфигурации systemd и активация таймера
if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload || true
    systemctl enable --now lsm-docker.timer || true
fi

if declare -f log_success >/dev/null 2>&1; then
    log_success "INSTALL" "Модуль мониторинга Docker успешно установлен."
else
    echo "Модуль мониторинга Docker успешно установлен."
fi
