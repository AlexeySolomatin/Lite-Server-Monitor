#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Команда обновления системы
#
# Путь:
#   commands/update.sh
#
# Назначение:
#   Обновление установленной копии LSM до актуальной версии.
#
# ==============================================================================

set -Eeuo pipefail

LSM_ROOT="${LSM_ROOT:-/opt/lsm}"

if [[ -f "${LSM_ROOT}/lib/core/common.sh" ]]; then source "${LSM_ROOT}/lib/core/common.sh"; fi
if [[ -f "${LSM_ROOT}/lib/core/ui.sh" ]]; then source "${LSM_ROOT}/lib/core/ui.sh"; fi

check_root

log_info "Проверка обновлений Lite Server Monitor..."

if [[ -d "${LSM_ROOT}/.git" ]]; then
    log_info "Обновление кодовой базы через Git..."
    git -C "${LSM_ROOT}" pull --rebase || log_warn "Не удалось выполнить git pull. Продолжаем через повторный запуск установщика..."
fi

log_info "Повторный запуск установщика для применения обновлений..."
exec bash "${LSM_ROOT}/installer/install.sh" "$@"
