#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Инсталлятор модуля мониторинга Docker
# Путь: modules/docker/install.sh
# ==============================================================================

set -Eeuo pipefail

# Константы путей и модуля
LSM_ROOT="${LSM_ROOT:-/opt/lsm}"
LSM_CONF_DIR="/etc/lsm/modules"
MODULE_NAME="docker"
MODULE_DIR="${LSM_ROOT}/modules/${MODULE_NAME}"
SYSTEMD_DIR="/etc/systemd/system"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Подключение базовых библиотек ядра и деплоя
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

# Проверка прав root
if [[ "${EUID}" -ne 0 ]]; then
    if declare -f log_error >/dev/null 2>&1; then
        log_error "INSTALL" "Инсталлятор должен запускаться с правами root."
    else
        echo "Ошибка: Инсталлятор должен запускаться с правами root." >&2
    fi
    exit 1
fi

if declare -f log_info >/dev/null 2>&1; then
    log_info "INSTALL" "Установка модуля мониторинга Docker..."
else
    echo "Установка модуля мониторинга Docker..."
fi

# 1. Создание необходимых директорий
if declare -f deploy_create_directory >/dev/null 2>&1; then
    deploy_create_directory "${MODULE_DIR}" "755" "root" "root"
    deploy_create_directory "${LSM_CONF_DIR}" "755" "root" "root"
else
    mkdir -p "${MODULE_DIR}" "${LSM_CONF_DIR}"
    chmod 755 "${MODULE_DIR}" "${LSM_CONF_DIR}"
fi

# 2. Установка основного скрипта проверки
SRC_CHECK="${SCRIPT_DIR}/files/check_docker.sh"
TARGET_CHECK="${MODULE_DIR}/check_docker.sh"

if [[ -f "${SRC_CHECK}" ]]; then
    if declare -f deploy_install_file >/dev/null 2>&1; then
        deploy_install_file "${SRC_CHECK}" "${TARGET_CHECK}" "755" "root" "root"
    else
        cp "${SRC_CHECK}" "${TARGET_CHECK}"
        chmod 755 "${TARGET_CHECK}"
    fi
else
    if declare -f log_error >/dev/null 2>&1; then
        log_error "INSTALL" "Файл исходного скрипта ${SRC_CHECK} не найден."
    else
        echo "Ошибка: Файл исходного скрипта ${SRC_CHECK} не найден." >&2
    fi
    exit 1
fi

# 3. Создание конфигурационного файла по умолчанию
CONF_FILE="${LSM_CONF_DIR}/docker.conf"
SRC_CONF="${SCRIPT_DIR}/templates/docker.conf"

if [[ ! -f "${CONF_FILE}" ]]; then
    if [[ -f "${SRC_CONF}" ]] && declare -f deploy_install_file >/dev/null 2>&1; then
        deploy_install_file "${SRC_CONF}" "${CONF_FILE}" "640" "root" "root"
    else
        cat << 'EOF' > "${CONF_FILE}"
# ==============================================================================
# Lite Server Monitor - Конфигурация модуля Docker
# Путь: /etc/lsm/modules/docker.conf
# ==============================================================================
DOCKER_ENABLED="true"
CHECK_SERVICE="true"
CHECK_CONTAINERS="true"
CHECK_STORAGE="true"
STOPPED_CONTAINER_WARNING="true"
STORAGE_WARNING_GB=50
EOF
        chmod 640 "${CONF_FILE}"
    fi

    if declare -f log_info >/dev/null 2>&1; then
        log_info "INSTALL" "Конфигурационный файл создан: ${CONF_FILE}"
    else
        echo "Конфигурационный файл создан: ${CONF_FILE}"
    fi
else
    if declare -f log_warn >/dev/null 2>&1; then
        log_warn "INSTALL" "Конфигурация ${CONF_FILE} уже существует, пропуск создания."
    else
        echo "Предупреждение: Конфигурация ${CONF_FILE} уже существует, пропуск создания." >&2
    fi
fi

# 4. Создание unit-файлов systemd
if declare -f log_info >/dev/null 2>&1; then
    log_info "INSTALL" "Настройка systemd сервиса и таймера..."
else
    echo "Настройка systemd сервиса и таймера..."
fi

SRC_SERVICE="${SCRIPT_DIR}/files/lsm-docker.service"
SRC_TIMER="${SCRIPT_DIR}/files/lsm-docker.timer"

if [[ -f "${SRC_SERVICE}" ]] && declare -f deploy_install_file >/dev/null 2>&1; then
    deploy_install_file "${SRC_SERVICE}" "${SYSTEMD_DIR}/lsm-docker.service" "644" "root" "root"
else
    cat << EOF > "${SYSTEMD_DIR}/lsm-docker.service"
[Unit]
Description=Lite Server Monitor - Docker Check Service
Documentation=https://github.com/AlexeySolomatin/Lite-Server-Monitor
After=network.target docker.service
Wants=docker.service

[Service]
Type=oneshot
ExecStart=/bin/bash ${MODULE_DIR}/check_docker.sh

User=root
Group=root

StandardOutput=journal
StandardError=journal
EOF
    chmod 644 "${SYSTEMD_DIR}/lsm-docker.service"
fi

if [[ -f "${SRC_TIMER}" ]] && declare -f deploy_install_file >/dev/null 2>&1; then
    deploy_install_file "${SRC_TIMER}" "${SYSTEMD_DIR}/lsm-docker.timer" "644" "root" "root"
else
    cat << EOF > "${SYSTEMD_DIR}/lsm-docker.timer"
[Unit]
Description=Lite Server Monitor - Docker Check Timer
Documentation=https://github.com/AlexeySolomatin/Lite-Server-Monitor

[Timer]
OnCalendar=*:0/15
AccuracySec=1m
Persistent=true
Unit=lsm-docker.service

[Install]
WantedBy=timers.target
EOF
    chmod 644 "${SYSTEMD_DIR}/lsm-docker.timer"
fi

# 5. Перезапуск systemd и активация таймера
if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload || true
    systemctl enable --now lsm-docker.timer >/dev/null 2>&1 || true
fi

if declare -f log_success >/dev/null 2>&1; then
    log_success "INSTALL" "Модуль мониторинга Docker успешно установлен."
else
    echo "Модуль мониторинга Docker успешно установлен."
fi
