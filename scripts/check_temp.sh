#!/usr/bin/env bash
set -o pipefail

STATE_DIR="/var/lib/print-monitor/state"
STATE_FILE="$STATE_DIR/temp_alert"
LOCK_FILE="$STATE_DIR/.temp_check.lock"

MAX_DISK_TEMP=45
MAX_CPU_TEMP=70

# Создаём директорию, если нет
mkdir -p "$STATE_DIR"
chown root:root "$STATE_DIR"
chmod 750 "$STATE_DIR"

(
  # Блокировка: если занята — тихо выходим, другой экземпляр уже работает
  if ! flock -n 200; then
    exit 0
  fi

  ALERT_TRIGGERED=0
  ALERT_MSG=""

  # --- 1. Проверка температур всех дисков (автоматический поиск) ---
  while IFS= read -r disk; do
    disk_name=$(basename "$disk")
    
    # Получаем температуру через smartctl
    raw_temp=$(smartctl -A "$disk" 2>/dev/null | awk '/Temperature_Celsius/ {print $10}')
    
    if [[ -n "$raw_temp" && "$raw_temp" =~ ^[0-9]+$ ]]; then
      if (( raw_temp >= MAX_DISK_TEMP )); then
        ALERT_TRIGGERED=1
        ALERT_MSG="${ALERT_MSG} ${disk_name}=${raw_temp}°C"
      fi
    fi
  done < <(find /dev -maxdepth 1 -type b \( -name 'sd*' -o -name 'nvme*' -o -name 'vd*' -o -name 'xvd*' \) ! -name '*loop*' ! -name '*ram*' 2>/dev/null)

  # --- 2. Проверка температуры CPU (исправленный парсинг целого числа) ---
  # Извлекаем строку с температурой, отсекаем всё после точки с помощью cut, затем убираем знаки плюс/минус
  cpu_line=$(sensors 2>/dev/null | grep -E 'Core|Package' | head -n 1 | awk '{print $4}')
  cpu_temp_raw=$(echo "$cpu_line" | cut -d. -f1 | tr -dc '0-9')
  
  if [[ -n "$cpu_temp_raw" && "$cpu_temp_raw" =~ ^[0-9]+$ ]]; then
    if (( cpu_temp_raw >= MAX_CPU_TEMP )); then
      ALERT_TRIGGERED=1
      ALERT_MSG="${ALERT_MSG} CPU=${cpu_temp_raw}°C"
    fi
  fi

  # --- Логика отправки алертов ---
  if (( ALERT_TRIGGERED == 1 )); then
    if [[ ! -f "$STATE_FILE" ]]; then
      touch "$STATE_FILE"
      /usr/local/bin/print_notify.sh "TEMPERATURE" "🔥 Внимание! Зафиксирован критический перегрев компонентов:${ALERT_MSG}" || true
    fi
  else
    if [[ -f "$STATE_FILE" ]]; then
      rm -f "$STATE_FILE"
      /usr/local/bin/print_notify.sh "TEMPERATURE" "✅ Восстановление! Температурный режим стабилизирован." || true
    fi
  fi

) 200> "$LOCK_FILE"
