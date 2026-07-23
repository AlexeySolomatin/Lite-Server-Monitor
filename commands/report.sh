#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# CLI Команда: Генератор ежедневного отчета (Report / Daily Digest)
# Путь: commands/report.sh
# ==============================================================================

set -Eeuo pipefail

LSM_ROOT="${LSM_ROOT:-/opt/lsm}"

# Подключение библиотек ядра
if [[ -f "${LSM_ROOT}/lib/core/common.sh" ]]; then source "${LSM_ROOT}/lib/core/common.sh"; fi
if [[ -f "${LSM_ROOT}/lib/core/ui.sh" ]]; then source "${LSM_ROOT}/lib/core/ui.sh"; fi
if [[ -f "${LSM_ROOT}/lib/core/report.sh" ]]; then source "${LSM_ROOT}/lib/core/report.sh"; fi

SEND_NOTIFICATION=false

# Разбор аргументов командной строки
for arg in "$@"; do
    case "${arg}" in
        --send|-s)
            SEND_NOTIFICATION=true
            ;;
    esac
done

# Выполнение генерации и отправка/вывод
if [[ "${SEND_NOTIFICATION}" == "true" ]]; then
    report_output="$(report_generate_full)"
    
    notify_script="${LSM_ROOT}/lib/notifications/notify.sh"
    if [[ -f "${notify_script}" && -x "${notify_script}" ]]; then
        "${notify_script}" "daily_report" "OK" "${report_output}"
        if declare -f log_success >/dev/null 2>&1; then
            log_success "Ежедневный отчет успешно отправлен через диспетчер уведомлений."
        fi
    else
        if declare -f log_error >/dev/null 2>&1; then
            log_error "Скрипт отправки уведомлений не найден или не исполняем: ${notify_script}"
        else
            echo "[!] Ошибка: Диспетчер уведомлений не найден по пути ${notify_script}" >&2
        fi
        exit 1
    fi
else
    if declare -f ui_section >/dev/null 2>&1; then
        ui_section "Диагностический отчет LSM"
    fi
    
    report_generate_full
    echo ""
    
    if declare -f log_success >/dev/null 2>&1; then
        log_success "Отчет успешно сформирован."
    fi
fi
