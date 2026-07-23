#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Генератор файлов конфигурации (Разделы 6 и 7)
# Путь: lib/installer/config_builder.sh
# ==============================================================================

set -Eeuo pipefail

build_lsm_configs() {
    local target_dir="${LSM_CONFIG_DIR:-/etc/lsm}"
    mkdir -p "${target_dir}"
    chmod 755 "${target_dir}"

    # 1. /etc/lsm/config.conf — Общие настройки
    cat <<EOF > "${target_dir}/config.conf"
# ==============================================================================
# LSM: Общие настройки системы
# ==============================================================================
LSM_ROOT="${LSM_ROOT:-/opt/lsm}"
LSM_LOG_DIR="${LSM_LOG_DIR:-/var/log/lsm}"
LSM_DATA_DIR="${LSM_DATA_DIR:-/var/lib/lsm}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"
EOF
    chmod 644 "${target_dir}/config.conf"

    # 2. /etc/lsm/modules.conf — Список активных модулей
    cat <<EOF > "${target_dir}/modules.conf"
# ==============================================================================
# LSM: Активные модули мониторинга
# ==============================================================================
ENABLED_MODULES=($(printf '"%s" ' "${SELECTED_MODULES[@]}"))
EOF
    chmod 644 "${target_dir}/modules.conf"

    # 3. /etc/lsm/notifications.conf — Настройки каналов оповещения
    cat <<EOF > "${target_dir}/notifications.conf"
# ==============================================================================
# LSM: Настройки уведомлений и анти-спама
# ==============================================================================
ALERT_COOLDOWN="${ALERT_COOLDOWN:-3600}"
TELEGRAM_ENABLED="${TELEGRAM_ENABLED:-false}"
EMAIL_ENABLED="${EMAIL_ENABLED:-false}"
ALERT_EMAIL="${ALERT_EMAIL:-}"
SMTP_SERVER="${SMTP_SERVER:-}"
SMTP_PORT="${SMTP_PORT:-587}"
SMTP_FROM="${SMTP_FROM:-}"
EOF
    chmod 644 "${target_dir}/notifications.conf"

    # 4. /etc/lsm/thresholds.conf — Пороговые значения
    cat <<EOF > "${target_dir}/thresholds.conf"
# ==============================================================================
# LSM: Пороговые значения срабатывания тревог
# ==============================================================================
DISK_WARN_PERCENT=${DISK_WARN_PERCENT:-85}
DISK_CRIT_PERCENT=${DISK_CRIT_PERCENT:-95}
CPU_WARN_PERCENT=${CPU_WARN_PERCENT:-80}
RAM_WARN_PERCENT=${RAM_WARN_PERCENT:-90}
TEMP_CRIT_CELSIUS=${TEMP_CRIT_CELSIUS:-80}
EOF
    chmod 644 "${target_dir}/thresholds.conf"

    # 5. /etc/lsm/secrets.conf — Секретные данные (Права 0600)
    cat <<EOF > "${target_dir}/secrets.conf"
# ==============================================================================
# LSM: Секретные ключи и пароли (Строгий доступ: chmod 0600)
# ==============================================================================
TG_BOT_TOKEN="${TG_BOT_TOKEN:-}"
TG_CHAT_ID="${TG_CHAT_ID:-}"
SMTP_USER="${SMTP_USER:-}"
SMTP_PASS="${SMTP_PASS:-}"
EOF
    chmod 600 "${target_dir}/secrets.conf"
    chown root:root "${target_dir}/secrets.conf" 2>/dev/null || true
}
