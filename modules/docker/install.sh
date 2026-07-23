#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Инсталлятор модуля Docker
# Путь: modules/docker/install.sh
# ==============================================================================

set -Eeuo pipefail

# Константы путей
LSM_ROOT="${LSM_ROOT:-/opt/lsm}"
LSM_CONF_DIR="/etc/lsm/modules"
MODULE_NAME="docker"
MODULE_DIR="${LSM_ROOT}/modules/${MODULE_NAME}"
SYSTEMD_DIR="/etc/systemd/system"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Проверка прав Root
if [[ "${EUID}" -ne 0 ]]; then
    echo "[!] Ошибка: Инсталлятор должен запускаться с правами root." >&2
    exit 1
fi

echo "[*] Установка модуля LSM: Docker..."

# 1. Создание необходимых директорий
mkdir -p "${MODULE_DIR}"
mkdir -p "${LSM_CONF_DIR}"

# 2. Установка основного скрипта проверки
SRC_CHECK="${SCRIPT_DIR}/files/check_docker.sh"
if [[ -f "${SRC_CHECK}" ]]; then
    cp "${SRC_CHECK}" "${MODULE_DIR}/check_docker.sh"
    chmod 755 "${MODULE_DIR}/check_docker.sh"
    echo "[+] Скрипт проверки скопирован в ${MODULE_DIR}/check_docker.sh"
else
    echo "[!] Ошибка: Файл ${SRC_CHECK} не найден!" >&2
    exit 1
fi

# 3. Создание конфигурационного файла по умолчанию
CONF_FILE="${LSM_CONF_DIR}/docker.conf"
if [[ ! -f "${CONF_FILE}" ]]; then
    cat << 'EOF' > "${CONF_FILE}"
# ==============================================================================
# Lite Server Monitor - Конфигурация модуля Docker
# ==============================================================================
ENABLED=true
CHECK_SERVICE=true
CHECK_CONTAINERS=true
CHECK_STORAGE=true
STOPPED_CONTAINER_WARNING=true
STORAGE_WARNING_GB=50
EOF
    chmod 644 "${CONF_FILE}"
    echo "[+] Конфигурационный файл создан: ${CONF_FILE}"
else
    echo "[i] Конфигурация ${CONF_FILE} уже существует, пропуск создания."
fi

# 4. Создание unit-файлов systemd
echo "[*] Настройка systemd сервиса и таймера..."

cat << EOF > "${SYSTEMD_DIR}/lsm-docker.service"
[Unit]
Description=Lite Server Monitor - Docker Check Service
After=docker.service

[Service]
Type=oneshot
ExecStart=${MODULE_DIR}/check_docker.sh
EOF

cat << EOF > "${SYSTEMD_DIR}/lsm-docker.timer"
[Unit]
Description=Lite Server Monitor - Docker Check Timer (Every 15 min)

[Timer]
OnCalendar=*:0/15
Persistent=true

[Install]
WantedBy=timers.target
EOF

chmod 644 "${SYSTEMD_DIR}/lsm-docker.service" "${SYSTEMD_DIR}/lsm-docker.timer"

# 5. Перезапуск systemd и активация таймера
systemctl daemon-reload
systemctl enable --now lsm-docker.timer >/dev/null 2>&1

echo "[+] Таймер lsm-docker.timer успешно запущен (интервал: каждые 15 минут)."
echo "[✔] Модуль Docker успешно установлен!"
