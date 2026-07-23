#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Библиотека управления конфигурационными файлами
# Путь: lib/core/config.sh
# ==============================================================================

set -Eeuo pipefail

# Защита от повторного подключения файла
[[ -n "${LSM_CONFIG_LOADED:-}" ]] && return 0
readonly LSM_CONFIG_LOADED=1

# Значения путей по умолчанию
: "${LSM_CONFIG_DIR:=/etc/lsm}"
: "${CONFIG_DIR:=${LSM_CONFIG_DIR}}"
: "${CONFIG_FILE:=${CONFIG_DIR}/config.conf}"
: "${TEMPLATES_DIR:=${LSM_ROOT:-/opt/lsm}/templates}"

#
# Проверка существования основного конфигурационного файла
#
config_exists() {
    local target_file="${1:-${CONFIG_FILE}}"
    [[ -f "${target_file}" ]]
}

#
# Загрузка основного конфигурационного файла
#
load_config() {
    local target_file="${1:-${CONFIG_FILE}}"

    if [[ ! -f "${target_file}" ]]; then
        if declare -f log_error >/dev/null 2>&1; then
            log_error "CONFIG" "Конфигурационный файл не найден: ${target_file}"
        else
            echo "Ошибка: Конфигурационный файл не найден: ${target_file}" >&2
        fi
        return 1
    fi

    # shellcheck source=/dev/null
    source "${target_file}"
}

#
# Последовательная загрузка всех модульных конфигов (/etc/lsm/*.conf)
#
load_all_configs() {
    local config_files=(
        "config.conf"
        "modules.conf"
        "notifications.conf"
        "thresholds.conf"
        "secrets.conf"
    )

    for cfg in "${config_files[@]}"; do
        local cfg_path="${CONFIG_DIR}/${cfg}"
        if [[ -f "${cfg_path}" ]]; then
            if [[ "${cfg}" == "secrets.conf" ]]; then
                chmod 600 "${cfg_path}" 2>/dev/null || true
            fi
            # shellcheck source=/dev/null
            source "${cfg_path}"
        fi
    done
}

#
# Валидация ключевых параметров конфигурации
#
validate_config() {
    local errors=0

    if [[ -z "${LSM_HOSTNAME:-}" ]]; then
        # Автоматический фоллбэк на имя хоста системы, если не задано явно
        export LSM_HOSTNAME="$(hostname -s 2>/dev/null || echo "unknown-host")"
        if declare -f log_warn >/dev/null 2>&1; then
            log_warn "CONFIG" "Переменная LSM_HOSTNAME не задана. Установлено значение по умолчанию: ${LSM_HOSTNAME}"
        fi
    fi

    if [[ -z "${REPORT_TIME:-}" ]]; then
        if declare -f log_error >/dev/null 2>&1; then
            log_error "CONFIG" "Переменная REPORT_TIME не сконфигурирована."
        else
            echo "Ошибка: Переменная REPORT_TIME не сконфигурирована." >&2
        fi
        ((errors++)) || true
    fi

    return "${errors}"
}

#
# Создание директории конфигурации с правильными правами доступа
#
create_config_dir() {
    if declare -f ensure_directory >/dev/null 2>&1; then
        ensure_directory "${CONFIG_DIR}"
    else
        mkdir -p "${CONFIG_DIR}"
    fi

    chmod 750 "${CONFIG_DIR}"
}

#
# Установка базовой конфигурации из шаблонов
#
install_default_config() {
    if config_exists; then
        if declare -f log_info >/dev/null 2>&1; then
            log_info "CONFIG" "Конфигурационный файл уже существует: ${CONFIG_FILE}"
        fi
        return 0
    fi

    create_config_dir

    if [[ -f "${TEMPLATES_DIR}/config.conf" ]]; then
        cp "${TEMPLATES_DIR}/config.conf" "${CONFIG_FILE}"
        chmod 640 "${CONFIG_FILE}"

        if declare -f log_success >/dev/null 2>&1; then
            log_success "CONFIG" "Базовый конфигурационный файл успешно установлен."
        fi
    else
        if declare -f log_error >/dev/null 2>&1; then
            log_error "CONFIG" "Шаблон конфигурации не найден по пути: ${TEMPLATES_DIR}/config.conf"
        fi
        return 1
    fi
}
