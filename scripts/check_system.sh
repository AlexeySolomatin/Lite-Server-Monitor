#!/usr/bin/env bash
set -o pipefail

STATE_DIR="/var/lib/print-monitor/state"
STATE_FILE="$STATE_DIR/system_alert"
LOCK_FILE="$STATE_DIR/.system_check.lock"

# Пороги срабатывания
CPU_CORES=$(nproc 2>/dev/null || echo "1")
# Используем 1.5x от числа ядер как порог для 1‑мин нагрузки, чтобы избежать ложных срабатываний
MAX_LOAD_THRESHOLD=$(awk "BEGIN {printf \"%.1f\", $CPU_CORES * 1.5}")
MAX_RAM=90

mkdir -p "$STATE_DIR"
chown root:root "$STATE_DIR"
chmod 750 "$STATE_DIR"

(
  if ! flock -n 200; then
    exit 0
  fi

  ALERT_TRIGGERED=0
  ALERT_MSG=""

  # Проверка Load Average: берём 1‑минутную и 5‑минутную
  read -r load1 load5 load15 _ < /proc/loadavg

  # Сравниваем с порогом (с плавающей точкой)
  # Используем bc для корректного сравнения float
  if command -v bc >/dev/null 2>&1; then
    if (( $(echo "$load1 >= $MAX_LOAD_THRESHOLD" | bc -l) )); then
      ALERT_TRIGGERED=1
      ALERT_MSG="${ALERT_MSG} Load=${load1} (Порог: ${MAX_LOAD_THRESHOLD})"
    fi
  else
    # Fallback без bc: округляем до целого и сравниваем грубо
    load1_int=$(awk "BEGIN {printf \"%d\", $load1}")
    threshold_int=$(awk "BEGIN {printf \"%d\", $MAX_LOAD_THRESHOLD}")
    if [[ "$load1_int" -ge "$threshold_int" ]]; then
      ALERT_TRIGGERED=1
      ALERT_MSG="${ALERT_MSG} Load=${load1} (Порог: ${MAX_LOAD_THRESHOLD})"
    fi
  fi

  # Проверка RAM: исправленный синтаксис awk
  RAM_PERCENT=$(free 2>/dev/null | awk '/^Mem:/ || /^Total:/ {printf "%.0f", ($3/$2) * 100}')
  
  # Если RAM_PERCENT пустой (ошибка free), считаем OK, чтобы не падать
  if [[ -n "$RAM_PERCENT" && "$RAM_PERCENT" -ge "$MAX_RAM" ]]; then
    ALERT_TRIGGERED=1
    ALERT_MSG="${ALERT_MSG} RAM=${RAM_PERCENT}% (Порог: ${MAX_RAM}%)"
  fi

  if (( ALERT_TRIGGERED == 1 )); then
    if [[ ! -f "$STATE_FILE" ]]; then
      touch "$STATE_FILE"
      /usr/local/bin/print_notify.sh "SYSTEM" "🔥 Внимание! Повышенная нагрузка на сервер:${ALERT_MSG}" || true
    fi
  else
    if [[ -f "$STATE_FILE" ]]; then
      rm -f "$STATE_FILE"
      /usr/local/bin/print_notify.sh "SYSTEM" "✅ Восстановление! Нагрузка на систему вернулась в штатные рамки." || true
    fi
  fi

) 200> "$LOCK_FILE"
