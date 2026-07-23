#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Библиотека: Генератор системных отчетов
# Путь: lib/core/report.sh
# Назначение: Вспомогательные функции сбора данных и формирования ежедневного отчета.
# ==============================================================================

# Защита от повторного подключения (Include guard)
if [[ -n "${_LSM_LIB_REPORT_SH:-}" ]]; then
    return 0
fi
_LSM_LIB_REPORT_SH=1

# Строгий режим выполнения
set -euo pipefail

# ------------------------------------------------------------------------------
# Функция: report_get_header
# Назначение: Формирует стандартный заголовок отчета с системной информацией.
# Вывод: Отформатированный текст заголовка в stdout.
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
# Функция: report_collect_modules
# Назначение: Опрашивает установленные модули LSM и собирает их статус/отчеты.
# Вывод: Блоки текста по каждому модулю в stdout.
# ------------------------------------------------------------------------------
report_collect_modules() {
    local modules_dir="${LSM_MODULES_DIR:-/usr/local/lib/lsm/modules}"
    local found_any=0
    local mod_path mod_name check_script

    if [[ ! -d "${modules_dir}" ]]; then
        echo "[!] Директория модулей не найдена: ${modules_dir}"
        return 1
    fi

    for mod_path in "${modules_dir}"/*; do
        [[ -d "${mod_path}" ]] || continue
        
        mod_name="$(basename "${mod_path}")"
        # Пропускаем служебный модуль ядра, если он присутствует
        [[ "${mod_name}" == "core" ]] && continue
        
        check_script=""
        if [[ -f "${mod_path}/files/check_${mod_name}.sh" ]]; then
            check_script="${mod_path}/files/check_${mod_name}.sh"
        elif [[ -f "${mod_path}/check.sh" ]]; then
            check_script="${mod_path}/check.sh"
        fi

        if [[ -n "${check_script}" && -x "${check_script}" ]]; then
            found_any=1
            echo ""
            echo "--- Модуль: ${mod_name^^} ---"
            
            # Если скрипт поддерживает ключ --report, вызываем его, иначе стандартную проверку
            if "${check_script}" --help 2>&1 | grep -q -- '--report'; then
                "${check_script}" --report || echo "[!] Модуль ${mod_name} завершил отчет с ошибкой."
            else
                "${check_script}" || echo "[!] Модуль ${mod_name} завершил проверку с ошибкой."
            fi
        fi
    done

    if [[ ${found_any} -eq 0 ]]; then
        echo ""
        echo "[i] Активные модули мониторинга не обнаружены."
    fi
}

# ------------------------------------------------------------------------------
# Функция: report_generate_full
# Назначение: Собирает полный текст отчета (Заголовок + Модули + Подвал).
# Вывод: Полный текст отчета в stdout.
# ------------------------------------------------------------------------------
report_generate_full() {
    report_get_header
    report_collect_modules
    echo ""
    echo "=============================================================================="
    echo " Отчет сформирован LSM v${LSM_VERSION:-1.0.0}"
    echo "=============================================================================="
}
