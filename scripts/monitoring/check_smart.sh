#!/usr/bin/env bash
set -o pipefail

STATE_DIR="/var/lib/print-monitor/state"
LOCK_FILE="$STATE_DIR/.smart_check.lock"

mkdir -p "$STATE_DIR"
chown root:root "$STATE_DIR"
chmod 750 "$STATE_DIR"

(
  # Блокировка: если занята — тихо выходим
  if ! flock -n 200; then
    exit 0
  fi

  # Автоматически находим все физические диски (sd*, nvme*, vd*, xvd*), исключая loop/ram
  while IFS= read -r DISK; do
    [ -z "$DISK" ] && continue
    DISK_NAME=$(basename "$DISK")
    STATE_FILE="$STATE_DIR/smart_alert_${DISK_NAME}"

    # ПРОВЕРКА ЗДОРОВЬЯ ЧЕРЕЗ КОД ВОЗВРАТА (самый надёжный способ)
    if ! smartctl -H "$DISK" >/dev/null 2>&1; then
      # Статус НЕ PASSED (FAILED, ERROR, или утилита не смогла прочитать)
      if [[ ! -f "$STATE_FILE" ]]; then
        touch "$STATE_FILE"
        /usr/local/bin/print_notify.sh "SMART" "❌ Критическая ошибка! Накопитель $DISK провалил аппаратный тест здоровья SMART. Требуется срочная замена!" || true
      fi
    else
      # Статус PASSED
      if [[ -f "$STATE_FILE" ]]; then
        rm -f "$STATE_FILE"
        /usr/local/bin/print_notify.sh "SMART" "✅ Восстановление! Накопитель $DISK успешно прошёл повторный тест здоровья SMART." || true
      fi
    fi
  done < <(find /dev -maxdepth 1 -type b \( -name 'sd*' -o -name 'nvme*' -o -name 'vd*' -o -name 'xvd*' \) ! -name '*loop*' ! -name '*ram*' 2>/dev/null)

) 200> "$LOCK_FILE"
