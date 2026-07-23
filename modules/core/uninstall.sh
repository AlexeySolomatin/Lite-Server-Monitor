#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Скрипт удаления системных юнитов ежедневных отчетов (Модуль Core)
# Путь: modules/core/uninstall.sh
# ==============================================================================

set -Eeuo pipefail

LSM_ROOT="${LSM_ROOT:-/opt/lsm}"
SYSTEMD_DIR="/etc/systemd/system"

# Подключение базовых библиотек, если доступны
if [[ -f "${LSM_ROOT}/lib/core/common.sh" ]]; then
    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/core/common.sh"
fi

if [[ -f "${LSM_ROOT}/lib/core/ui.sh" ]]; then
    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/core/ui.sh"
fi

if declare -f log_info >/dev/null 2>&1; then
    log_info "UNINSTALL" "Остановка и удаление системных юнитов отчетов LSM..."
else
    echo "Остановка и удаление системных юнитов отчетов LSM..."
fi

# 1. Остановка и отключение таймера/сервиса systemd
if command -v systemctl >/dev/null 2>&1; then
    systemctl stop lsm-report.timer 2>/dev/null || true
    systemctl disable lsm-report.timer 2>/dev/null || true
    systemctl stop lsm-report.service 2>/dev/null || true
fi

# 2. Удаление файлов юнитов
rm -f "${SYSTEMD_DIR}/lsm-report.service"
rm -f "${SYSTEMD_DIR}/lsm-report.timer"

# 3. Перезагрузка конфигурации systemd
if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload || true
    systemctl reset-failed 2>/dev/null || true
fi

if declare -f log_success >/dev/null 2>&1; then
    log_success "UNINSTALL" "Юниты lsm-report успешно удалены."
else
    echo "Юниты lsm-report успешно удалены."
fi
