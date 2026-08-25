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
if [[ -f "${LSM_ROOT}/lib/core/logging.sh" ]]; then source "${LSM_ROOT}/lib/core/logging.sh"; fi
if [[ -f "${LSM_ROOT}/lib/core/ui.sh" ]]; then source "${LSM_ROOT}/lib/core/ui.sh"; fi

#
# Резервные реализации.
#
# Команда обновления обязана работать даже на поврежденной установке:
# без этих шимов падение log_* под set -e убивает скрипт ДО git pull,
# и установка не может обновить саму себя (замкнутый круг).
#

if ! declare -F log_info >/dev/null 2>&1; then
    log_info() { printf '%s\n' "$*"; }
fi

if ! declare -F log_warn >/dev/null 2>&1; then
    log_warn() { printf 'Предупреждение: %s\n' "$*" >&2; }
fi

if ! declare -F check_root >/dev/null 2>&1; then
    check_root() {
        if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
            echo "Ошибка: обновление требует прав root." >&2
            exit 1
        fi
    }
fi

check_root

log_info "Проверка обновлений Lite Server Monitor..."

if [[ -d "${LSM_ROOT}/.git" ]]; then
    log_info "Обновление кодовой базы через Git..."
    git -C "${LSM_ROOT}" pull --rebase || log_warn "Не удалось выполнить git pull. Продолжаем через повторный запуск установщика..."
fi

log_info "Повторный запуск установщика для применения обновлений..."
exec bash "${LSM_ROOT}/installer/install.sh" "$@"
