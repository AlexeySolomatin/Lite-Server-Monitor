#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Библиотека: Генератор системных отчетов
# Путь: lib/core/report.sh
# Описание: Функции сбора метрик и агрегации данных для ежедневного отчета.
# ==============================================================================

if [[ -n "${_LSM_LIB_REPORT_SH:-}" ]]; then
    return 0
fi
_LSM_LIB_REPORT_SH=1

set -euo pipefail

# ------------------------------------------------------------------------------
# Заголовок отчета
# ------------------------------------------------------------------------------
report_get_header() {
    local hostname_str uptime_str load_avg date_str
    
    hostname_str="$(hostname -f 2>/dev/null || hostname)"
    uptime_str="$(uptime -p 2>/dev/null || uptime)"
    
    if [[ -r /proc/loadavg ]]; then
        load_avg="$(cut -d' ' -f1-3 /proc/loadavg)"
    else
        load_avg="Н/Д"
    fi
    
    date_str="$(date '+%Y-%m-%d %H:%M:%S %Z')"

    cat <<EOF
==============================================================================
 LITE SERVER MONITOR (LSM) — ЕЖЕДНЕВНЫЙ СИСТЕМНЫЙ ОТЧЕТ
==============================================================================
 Имя хоста        : ${hostname_str}
 Дата и время     : ${date_str}
 Время работы     : ${uptime_str}
 Средняя нагрузка : ${load_avg}
==============================================================================
EOF
}

# ------------------------------------------------------------------------------
# Базовые системные метрики (Память, Диски, Процессы)
# ------------------------------------------------------------------------------
report_get_system_metrics() {
    echo -e "\n--- Использование оперативной памяти ---"
    free -h 2>/dev/null || echo "Не удалось получить данные ОЗУ"

    echo -e "\n--- Использование файловых систем ---"
    df -h -x tmpfs -x devtmpfs -x squashfs 2>/dev/null || echo "Не удалось получить данные дисков"

    echo -e "\n--- Топ-5 процессов по использованию CPU ---"
    ps aux --sort=-%cpu 2>/dev/null | head -n 6 || true

    echo -e "\n--- Топ-5 процессов по использованию RAM ---"
    ps aux --sort=-%mem 2>/dev/null | head -n 6 || true
}

# ------------------------------------------------------------------------------
# Проверка активных предупреждений (State-файлы)
# ------------------------------------------------------------------------------
report_get_active_alerts() {
    local state_dir="${LSM_STATE_DIR:-/var/lib/lsm/state}"
    local state_file module_name state_data found_alerts=0

    echo -e "\n--- Активные предупреждения LSM ---"
    if [[ -d "${state_dir}" ]]; then
        for state_file in "${state_dir}"/*.state; do
            [[ -f "${state_file}" ]] || continue
            found_alerts=1
            module_name="$(basename "${state_file}" .state)"
            state_data="$(cat "${state_file}")"
            echo "  - [ТРЕВОГА] Модуль '${module_name}': ${state_data#*|}"
        done
    fi

    if [[ ${found_alerts} -eq 0 ]]; then
        echo "  Все системы работают штатно. Активных предупреждений нет."
    fi
}

# ------------------------------------------------------------------------------
# Опрос установленных модулей LSM
# ------------------------------------------------------------------------------
report_collect_modules() {
    local modules_dir="${LSM_MODULES_DIR:-${LSM_ROOT:-/opt/lsm}/modules}"
    local found_any=0
    local mod_path mod_name check_script

    if [[ ! -d "${modules_dir}" ]]; then
        return 0
    fi

    for mod_path in "${modules_dir}"/*; do
        [[ -d "${mod_path}" ]] || continue
        
        mod_name="$(basename "${mod_path}")"
        [[ "${mod_name}" == "core" ]] && continue
        
        check_script=""
        if [[ -f "${mod_path}/files/check_${mod_name}.sh" ]]; then
            check_script="${mod_path}/files/check_${mod_name}.sh"
        elif [[ -f "${mod_path}/check.sh" ]]; then
            check_script="${mod_path}/check.sh"
        fi

        if [[ -n "${check_script}" && -x "${check_script}" ]]; then
            found_any=1
            echo -e "\n--- Модуль: ${mod_name^^} ---"
            
            if "${check_script}" --help 2>&1 | grep -q -- '--report'; then
                "${check_script}" --report || echo "[!] Модуль ${mod_name} завершил отчет с ошибкой."
            else
                "${check_script}" || echo "[!] Модуль ${mod_name} завершил проверку с ошибкой."
            fi
        fi
    done
}

# ------------------------------------------------------------------------------
# Полная сборка отчета
# ------------------------------------------------------------------------------
report_generate_full() {
    report_get_header
    report_get_system_metrics
    report_get_active_alerts
    report_collect_modules
    echo ""
    echo "=============================================================================="
    echo " Отчет сформирован LSM v${LSM_VERSION:-1.0.0}"
    echo "=============================================================================="
}
