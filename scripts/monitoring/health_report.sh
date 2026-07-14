#!/bin/bash
set -o pipefail

# --- Конфигурация ---
REPORT_STATE_FILE="/var/lib/print-monitor/state/last_health_report"
LOG_FILE="/var/log/print-monitor/health_report.log"
NOTIFY_SCRIPT="/usr/local/bin/print_notify.sh"

mkdir -p "$(dirname "$REPORT_STATE_FILE")"

# --- 1. Защита от спама (1 раз в сутки) ---
TODAY=$(date +%Y-%m-%d)
if [[ -f "$REPORT_STATE_FILE" ]]; then
    LAST_DATE=$(cat "$REPORT_STATE_FILE")
    if [[ "$LAST_DATE" == "$TODAY" ]]; then
        exit 0
    fi
fi

log_msg() {
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Сбор базовых метрик
UPTIME_INFO=$(uptime -p 2>/dev/null || echo "N/A")
LOAD_AVG=$(awk '{print $1, $2, $3}' /proc/loadavg 2>/dev/null || echo "N/A")

RAM_LINE=$(free -h 2>/dev/null | grep -i "^Mem:" || free -h 2>/dev/null | grep -i "^total:")
if [[ -n "$RAM_LINE" ]]; then
    RAM_USED=$(echo "$RAM_LINE" | awk '{print $3}')
    RAM_TOTAL=$(echo "$RAM_LINE" | awk '{print $2}')
    RAM_USAGE="${RAM_USED}/${RAM_TOTAL}"
else
    RAM_USAGE="N/A"
fi

DISK_ROOT=$(df -h / 2>/dev/null | awk 'NR==2 {print $5 " (Свободно: " $4 ")"}' || echo "N/A")

# --- Проверка RAID ---
RAID_STATUS="✅ OK"
RAID_DETAILS=""
if command -v mdadm >/dev/null 2>&1; then
    mapfile -t md_devices < <(awk '/^md/ {print $1}' /proc/mdstat 2>/dev/null)
    for dev_name in "${md_devices[@]}"; do
        [ -z "$dev_name" ] && continue
        dev="/dev/$dev_name"
        state=$(mdadm --detail "$dev" 2>/dev/null | grep "State :" | awk -F':' '{print $2}' | xargs)
        if [[ "$state" == *"degraded"* || "$state" == *"failed"* ]]; then
            RAID_STATUS="❌ DEGRADED"
            RAID_DETAILS="${RAID_DETAILS}\n   • ${dev}: ${state}"
        fi
    done
else
    RAID_STATUS="⚠️ mdadm not found"
fi

# Температура CPU
CPU_TEMP="N/A"
if command -v sensors >/dev/null 2>&1; then
    CPU_TEMP=$(sensors 2>/dev/null | awk '/Core 0/ || /Package-id-0/ || /Package id 0/ {print $4; exit}')
    [[ -z "$CPU_TEMP" ]] && CPU_TEMP="N/A"
fi

# Статус ИБП
UPS_STATUS="N/A"
if command -v apcaccess >/dev/null 2>&1; then
    UPS_STATUS=$(apcaccess status 2>/dev/null | awk -F': ' '/^STATUS/ {print $2; exit}' | xargs)
    [[ -z "$UPS_STATUS" ]] && UPS_STATUS="N/A"
fi

# --- Умный мониторинг Docker-контейнеров (Исправлены переносы строк) ---
DOCKER_STATUS="🟢 Не установлен/Нет контейнеров"
DOCKER_DETAILS=""

if command -v docker >/dev/null 2>&1; then
    if systemctl is-active --quiet docker; then
        TOTAL_CONTAINERS=$(docker ps -a -q | wc -l)
        RUNNING_CONTAINERS=$(docker ps -q | wc -l)
        
        if [ "$TOTAL_CONTAINERS" -gt 0 ]; then
            DOCKER_STATUS="🟢 Работает ($RUNNING_CONTAINERS/$TOTAL_CONTAINERS)"
            
            # Собираем детальную информацию. Использование реального символа перевода строки
            while read -r c_id c_name c_status; do
                DOCKER_DETAILS="${DOCKER_DETAILS}
   • ${c_name}: ${c_status}"
            done < <(docker ps -a --format "{{.ID}} {{.Names}} {{.Status}}")
        else
            DOCKER_STATUS="🟢 Демон активен (Контейнеров нет)"
        fi
    else
        DOCKER_STATUS="🔴 Демон Docker остановлен"
    fi
fi

# Сборка финального текста отчета
REPORT_MSG="📋 Ежедневный отчёт состояния узла ($(hostname))

⏱️ Время работы: $UPTIME_INFO
📊 Нагрузка (LA): $LOAD_AVG
🧠 Память (RAM): $RAM_USAGE
💾 Состояние массива: $RAID_STATUS${RAID_DETAILS:+\n$RAID_DETAILS}
💽 Корневой раздел: $DISK_ROOT
🌡️ Температура ЦП: $CPU_TEMP
⚡ Статус ИБП: $UPS_STATUS
📦 Состояние контейнеров: $DOCKER_STATUS$DOCKER_DETAILS

🤖 Отчёт сформирован автоматически."

# Отправка
if "$NOTIFY_SCRIPT" "HEALTH" "$REPORT_MSG"; then
    log_msg "Отчёт успешно отправлен."
    echo "$TODAY" > "$REPORT_STATE_FILE"
else
    log_msg "ОШИБКА: Не удалось отправить отчёт."
    exit 1
fi
