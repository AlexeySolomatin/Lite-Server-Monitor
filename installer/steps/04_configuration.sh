#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Step 04: Configuration Deployment
# -----------------------------------------------------------------------------

set -Eeuo pipefail

step_configuration() {
    log_info "Deploying default configuration files..."

    local config_dir="/etc/lsm"
    local config_file="${config_dir}/config.conf"
    local template_source="${LSM_ROOT:-/opt/lsm}/templates/config.conf"

    # 1. Гарантируем наличие целевой директории для конфигурации
    if declare -f deploy_create_directory >/dev/null 2>&1; then
        deploy_create_directory "${config_dir}" "755" "root" "root"
    else
        mkdir -p "${config_dir}"
        chmod 755 "${config_dir}"
        chown root:root "${config_dir}"
    fi

    # 2. Проверяем существование файла-шаблона в дистрибутиве
    if [[ ! -f "${template_source}" ]]; then
        log_error "Source template file not found: ${template_source}"
        return 1
    fi

    # 3. Если конфигурация уже существует, создаем бэкап
    if [[ -f "${config_file}" ]]; then
        local backup_file="${config_file}.bak.$(date +%Y%m%d_%H%M%S)"
        log_warn "Existing configuration found. Creating backup: ${backup_file}"
        cp -a "${config_file}" "${backup_file}"
    fi

    # 4. Копируем конфигурацию с безопасными правами (640, root:root)
    log_info "Installing ${config_file}..."
    if declare -f deploy_install_file >/dev/null 2>&1; then
        deploy_install_file "${template_source}" "${config_file}" "640" "root" "root"
    else
        cp "${template_source}" "${config_file}"
        chmod 640 "${config_file}"
        chown root:root "${config_file}"
    fi

    log_success "Configuration deployment completed successfully."
}

# Автономный запуск шага (для отладки и тестирования)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    LSM_ROOT="${LSM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
    export LSM_ROOT

    if [[ -f "${LSM_ROOT}/lib/core/common.sh" ]]; then
        source "${LSM_ROOT}/lib/core/common.sh"
    fi
    if [[ -f "${LSM_ROOT}/lib/installer/deploy.sh" ]]; then
        source "${LSM_ROOT}/lib/installer/deploy.sh"
    fi

    step_configuration
fi
