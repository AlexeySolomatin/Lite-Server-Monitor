#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Скрипт установки модуля мониторинга ИБП (UPS)
# Путь: modules/ups/install.sh
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

log_info "UPS" "Установка модуля мониторинга ИБП (UPS)..."

# 1. Создание целевых директорий
deploy_create_directory "/etc/lsm/modules" "755" "root" "root"

# 2. Установка юнитов Systemd
#    Исполняемый файл уже развернут в /opt/lsm/modules/ups/files/check_ups.sh
if [[ -f "${MODULE_DIR}/files/lsm-ups.service" ]]; then
    deploy_install_file \
        "${MODULE_DIR}/files/lsm-ups.service" \
        "/etc/systemd/system/lsm-ups.service" \
        "644" "root" "root"
fi

if [[ -f "${MODULE_DIR}/files/lsm-ups.timer" ]]; then
    deploy_install_file \
        "${MODULE_DIR}/files/lsm-ups.timer" \
        "/etc/systemd/system/lsm-ups.timer" \
        "644" "root" "root"
fi

# 3. Установка конфигурационного файла (без перезаписи существующего)
if [[ -f "${MODULE_DIR}/templates/ups.conf" ]]; then
    if [[ ! -f "/etc/lsm/modules/ups.conf" ]]; then
        deploy_install_file \
            "${MODULE_DIR}/templates/ups.conf" \
            "/etc/lsm/modules/ups.conf" \
            "640" "root" "root"
    else
        log_warn "UPS" "Конфигурационный файл /etc/lsm/modules/ups.conf уже существует, пропуск перезаписи."
    fi
fi

# 4. Перезагрузка конфигурации systemd и активация таймера
if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload || true
    systemctl enable --now lsm-ups.timer || true
fi

log_success "UPS" "Модуль мониторинга ИБП (UPS) успешно установлен."
