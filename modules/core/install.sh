#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Скрипт установки системных юнитов ежедневных отчетов (Модуль Core)
# Путь: modules/core/install.sh
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
    log_info "INSTALL" "Установка системных юнитов ежедневных отчетов LSM..."
else
    echo "Установка системных юнитов ежедневных отчетов LSM..."
fi

# 1. Проверка наличия исходных файлов
if [[ ! -d "${MODULE_DIR}/files" ]]; then
    if declare -f log_error >/dev/null 2>&1; then
        log_error "INSTALL" "Директория с файлами не найдена по пути ${MODULE_DIR}/files"
    else
        echo "Ошибка: Директория с файлами не найдена по пути ${MODULE_DIR}/files" >&2
    fi
    exit 1
fi

# 2. Установка юнитов Systemd
if [[ -f "${MODULE_DIR}/files/lsm-report.service" ]]; then
    deploy_install_file \
        "${MODULE_DIR}/files/lsm-report.service" \
        "/etc/systemd/system/lsm-report.service" \
        "644" "root" "root"
fi

if [[ -f "${MODULE_DIR}/files/lsm-report.timer" ]]; then
    deploy_install_file \
        "${MODULE_DIR}/files/lsm-report.timer" \
        "/etc/systemd/system/lsm-report.timer" \
        "644" "root" "root"
fi

# 3. Перезагрузка конфигурации systemd и активация таймера!
if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload || true

    if ! systemctl enable lsm-report.timer; then

        if declare -f log_warn >/dev/null 2>&1; then
            log_warn "INSTALL" "Не удалось активировать таймер lsm-report.timer. Диагностика: systemctl status lsm-report.timer"
        else
            echo "Предупреждение: не удалось активировать таймер lsm-report.timer." >&2
        fi

    fi

    systemctl restart lsm-report.timer || true
fi

if declare -f log_success >/dev/null 2>&1; then
    log_success "INSTALL" "Таймер lsm-report.timer успешно активирован."
else
    echo "Таймер lsm-report.timer успешно активирован."
fi
