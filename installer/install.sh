#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Master Installation Script
# -----------------------------------------------------------------------------

set -Eeuo pipefail

# Вычисляем корень инсталлятора
INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LSM_ROOT="$(cd "${INSTALLER_DIR}/.." && pwd)"
export LSM_ROOT

# Загрузка core-библиотек
source "${LSM_ROOT}/lib/core/common.sh"
source "${LSM_ROOT}/lib/core/ui.sh"
source "${LSM_ROOT}/lib/installer/deploy.sh"
source "${LSM_ROOT}/lib/installer/packages.sh"

# Проверка прав Root
check_root

# Отображение баннера
ui_banner

log_info "Starting Lite Server Monitor (LSM) v${PROJECT_VERSION} installation..."

# Запуск шагов установки
STEPS=(
    "01_system_check.sh"
    "02_packages.sh"
    "03_directories.sh"
    "04_configuration.sh"
    "05_modules.sh"
    "06_services.sh"
    "07_permissions.sh"
)

for step_script in "${STEPS[@]}"; do
    step_path="${INSTALLER_DIR}/steps/${step_script}"
    if [[ -f "${step_path}" ]]; then
        log_info "Executing step: ${step_script}..."
        
        # shellcheck source=/dev/null
        source "${step_path}"
        
        step_func_name="step_$(echo "${step_script}" | sed -E 's/^[0-9]+_//; s/\.sh$//')"
        if declare -f "${step_func_name}" >/dev/null 2>&1; then
            "${step_func_name}"
        fi
    fi
done

# Создание симлинка бинарника для глобального доступа
deploy_create_symlink "${LSM_ROOT}/bin/lsm" "/usr/local/bin/lsm"

log_success "Lite Server Monitor installation completed successfully!"
log_info "Run 'lsm help' to see available commands."
