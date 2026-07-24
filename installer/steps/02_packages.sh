#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Шаг 02: Установка зависимостей и системных пакетов
# Путь: installer/steps/02_packages.sh
# ==============================================================================

set -Eeuo pipefail

step_packages() {
    log_info "Установка необходимых пакетов..."

    log_info "Обновление индекса пакетов APT..."
    if ! apt-get update -y; then
        log_warn "Сбой обновления APT. Очистка списков и повторная попытка..."
        rm -rf /var/lib/apt/lists/*
        apt-get update -y || log_warn "Обновление APT завершено с предупреждениями, продолжение установки..."
    fi

    # Список обязательных системных пакетов (включая dialog для TUI)
    local pkgs=(
        curl
        wget
        jq
        bc
        msmtp
        smartmontools
        mdadm
        lm-sensors
        fail2ban
        dialog
    )

    for pkg in "${pkgs[@]}"; do
        if dpkg -s "$pkg" &>/dev/null; then
            log_info "Пакет уже установлен: $pkg"
        else
            log_info "Установка пакета: $pkg..."
            DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
        fi
    done

    log_success "Все необходимые пакеты успешно установлены."
}

# Автономный запуск шага
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    LSM_ROOT="${LSM_ROOT:-/opt/lsm}"
    export LSM_ROOT

    if [[ -f "${LSM_ROOT}/lib/core/common.sh" ]]; then source "${LSM_ROOT}/lib/core/common.sh"; fi
    if [[ -f "${LSM_ROOT}/lib/core/ui.sh" ]]; then source "${LSM_ROOT}/lib/core/ui.sh"; fi

    step_packages
fi
