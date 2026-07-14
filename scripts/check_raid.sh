#!/bin/bash
set -o pipefail

# Конфигурация
STATE_DIR="/var/lib/print-monitor/state"
STATE_FILE="$STATE_DIR/raid_alert"
LOCK_FILE="$STATE_DIR/.raid_check.lock"

# 1. Гарантированно создаём директорию с правильными правами
mkdir -p "$STATE_DIR" || {
  echo "Ошибка: не удалось создать директорию $STATE_DIR" >&2
  exit 1
}
chown root:root "$STATE_DIR"
chmod 750 "$STATE_DIR"

# 2. Блокировка от параллельных запусков
(
  # Пытаемся получить неблокирующую блокировку. Если не вышло — выходим.
  if ! flock -n 200; then
    echo "Предупреждение: блокировка занята, другой экземпляр уже работает. Пропуск проверки." >&2
    exit 0
  fi

  ALERT_TRIGGERED=0
  ALERT_MSG=""

  # 3. Универсальный сбор и проверка статуса RAID через mdadm
  # Регулярное выражение изменено: ищем любое слово, начинающееся на md в начале строки mdstat
  while IFS= read -r md_name; do
    [ -z "$md_name" ] && continue
    md_device="/dev/$md_name"
    
    # Проверяем детальный статус устройства.
    if mdadm --detail "$md_device" 2>/dev/null | grep -i 'State :' | grep -qE 'degraded|failed'; then
      ALERT_TRIGGERED=1
      status_line=$(mdadm --detail "$md_device" 2>/dev/null | grep -i 'State :')
      ALERT_MSG="${ALERT_MSG} ${md_device}: $(echo "$status_line" | xargs)"
    fi
  done < <(awk '/^md/ {print $1}' /proc/proc/mdstat 2>/dev/null || awk '/^md/ {print $1}' /proc/mdstat)

  # Если хоть один массив деградирован
  if [[ "$ALERT_TRIGGERED" -eq 1 ]]; then
    if [[ ! -f "$STATE_FILE" ]]; then
      # Меняем статус и шлем алерт
      touch "$STATE_FILE"
      /usr/local/bin/print_notify.sh "RAID" "❌ Критическая ошибка! Программный RAID-массив деградирован:${ALERT_MSG}" || true
      mkdir -p /var/log/print-monitor
      echo "[$(date)] RAID Alert sent: ${ALERT_MSG}" >> /var/log/print-monitor/raid.log
    fi
  else
    # Все массивы в норме
    if [[ -f "$STATE_FILE" ]]; then
      # Сбрасываем статус и шлем recovery
      rm -f "$STATE_FILE"
      /usr/local/bin/print_notify.sh "RAID" "✅ Восстановление! RAID-массивы находятся в статусе OK." || true
      mkdir -p /var/log/print-monitor
      echo "[$(date)] RAID Recovery sent" >> /var/log/print-monitor/raid.log
    fi
  fi

) 200> "$LOCK_FILE"
