#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Master Installation Script
# -----------------------------------------------------------------------------

set -Eeuo pipefail

# 1. Определение путей и экспорт окружения
INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LSM_ROOT="$(cd "${INSTALLER_DIR}/.." && pwd)"
export LSM_ROOT INSTALLER_DIR

# 2. Загрузка библиотек ядра и деплоя
# shellcheck source=/dev/null
source "${LSM_ROOT}/lib/core/common.sh"
# shellcheck source=/dev/null
source "${LSM_ROOT}/lib/core/ui.sh"
# shellcheck source=/dev/null
source "${LSM_ROOT}/lib/installer/deploy.sh"
# shellcheck source=/dev/null
source "${LSM_ROOT}/lib/installer/packages.sh"
# shellcheck source=/dev/null
source "${LSM_ROOT}/lib/installer/registry.sh"

# 3. Инициализация версии проекта
if [[ -f "${LSM_ROOT}/VERSION" ]]; then
    PROJECT_VERSION="$(tr -d '\r\n' < "${LSM_ROOT}/VERSION")"
else
    PROJECT_VERSION="${PROJECT_VERSION:-1.0.0}"
fi
export PROJECT_VERSION

# 4. Перехват ошибок
trap_install_error() {
    local exit_code=$?
    local line_no=$1
    echo
    log_error "Критическая ошибка во время установки на строке ${line_no} (код ответа: ${exit_code})."
    log_error "Установка Lite Server Monitor прервана."
    exit "${exit_code}"
}
trap 'trap_install_error $LINENO' ERR

# 5. Проверка прав суперпользователя
check_root

# 6. Обработка флагов запуска и мастера установки
NON_INTERACTIVE=false
if [[ "${1:-}" == "--quiet" || "${1:-}" == "--non-interactive" || "${1:-}" == "-y" ]]; then
    NON_INTERACTIVE=true
fi

registry_load_default

if [[ "${NON_INTERACTIVE}" == "false" ]]; then    
    if [[ -f "${INSTALLER_DIR}/wizard.sh" ]]; then
        # shellcheck source=/dev/null
        source "${INSTALLER_DIR}/wizard.sh"
        run_install_wizard
    fi
else
    log_info "Запуск установки в тихом режиме (Unattended mode)..."
    # Базовые значения для неинтерактивного режима
    INSTALL_MODE="${INSTALL_MODE:-full}"
    NOTIFICATION_METHOD="${NOTIFICATION_METHOD:-none}"
    SELECTED_MODULES=()


while read -r module; do

    if [[ "$(registry_default "${module}")" == "yes" ]]; then

        SELECTED_MODULES+=("${module}")

    fi

done < <(registry_list)
fi

# 7. Заголовок и логирование
ui_banner
log_info "Запуск установки Lite Server Monitor (LSM) v${PROJECT_VERSION}..."

# 8. Последовательное выполнение шагов
STEPS=(
    "01_environment.sh"
    "02_packages.sh"
    "03_directories.sh"
    "04_configuration.sh"
    "05_modules.sh"
    "06_services.sh"
    "07_permissions.sh"
    "08_finish.sh"
)

for step_script in "${STEPS[@]}"; do
    step_path="${INSTALLER_DIR}/steps/${step_script}"

    if [[ -f "${step_path}" ]]; then
        log_info "Выполнение шага: ${step_script}..."

        # shellcheck source=/dev/null
        source "${step_path}"

        step_func_name="step_$(echo "${step_script}" | sed -E 's/^[0-9]+_//; s/\.sh$//')"
        if declare -f "${step_func_name}" >/dev/null 2>&1; then
            "${step_func_name}"
        else
            log_warn "Функция '${step_func_name}' не найдена в файле ${step_script}."
        fi
    else
        log_error "Отсутствует обязательный файл шага: ${step_path}"
        exit 1
    fi
done

# 9. Создание глобального симлинка бинарника
deploy_create_symlink "${LSM_ROOT}/bin/lsm" "/usr/local/bin/lsm"

echo
log_success "Установка Lite Server Monitor (LSM) v${PROJECT_VERSION} успешно завершена!"
log_info "Запустите 'lsm help' для получения списка команд."
