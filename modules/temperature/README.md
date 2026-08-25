# Модуль контроля температуры

Модуль отслеживает температуру CPU и других компонентов системы. При превышении порогов отправляются уведомления WARNING/CRITICAL, при нормализации — recovery-сообщение. Работает как с пакетом lm-sensors, так и без него (через sysfs).

## Назначение

- Раннее обнаружение перегрева сервера.
- Информационная поддержка: краткий статус (`status`) и отчет по всем датчикам (`report`).

## Принцип работы

Источники данных:

1. Утилита `sensors` (пакет lm-sensors) — если установлена, парсятся все строки со значениями `+NN°C`.
2. Фолбэк `/sys/class/thermal/thermal_zone*/temp` — используется, если lm-sensors не установлен или не вернул данных. Имя датчика берется из файла `type` соответствующей зоны.

lm-sensors НЕ обязателен: при его отсутствии модуль использует фолбэк на `/sys/class/thermal`. Если датчиков нет вообще ни в одном источнике, проверка пропускается без ошибок.

Проверяются максимальные значения среди всех найденных датчиков:

| Уровень | Условие |
|---------|---------|
| CRITICAL | температура ≥ `CRITICAL_TEMP`; отправляется всегда |
| WARNING | температура ≥ `WARNING_TEMP`; только при `NOTIFY_ON_WARNING=true` |
| OK (recovery) | температура вернулась ниже порогов после алерта; только при `NOTIFY_ON_RECOVERY=true` |

Состояние алерта хранится в `/var/lib/lsm/state/temperature_alert`, поэтому повторные уведомления об одном и том же перегреве не спамят. Повторная отправка алертов также ограничена кулдауном `ALERT_COOLDOWN` (настраивается глобально).

Запуск выполняется таймером systemd `lsm-temperature.timer`: первый запуск через 5 минут после загрузки, далее каждые 5 минут. Параллельный запуск блокируется через `flock`.

## Параметры конфигурации

Файл: `/etc/lsm/modules/temperature.conf`

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `WARNING_TEMP` | `70` | WARNING-порог температуры, °C. |
| `CRITICAL_TEMP` | `80` | CRITICAL-порог температуры, °C. |
| `NOTIFY_ON_WARNING` | `true` | Отправлять WARNING-уведомления о перегреве (CRITICAL отправляются всегда). |
| `NOTIFY_ON_RECOVERY` | `true` | Отправлять recovery-уведомление (OK) при нормализации температуры. |

## Файлы модуля

| Путь | Назначение |
|------|-----------|
| `modules/temperature/files/check_temperature.sh` | Скрипт проверки (в репозитории) |
| `/opt/lsm/modules/temperature/files/check_temperature.sh` | Скрипт проверки (в системе) |
| `/etc/systemd/system/lsm-temperature.service` | Systemd-служба проверки |
| `/etc/systemd/system/lsm-temperature.timer` | Systemd-таймер (каждые 5 минут) |
| `/etc/lsm/modules/temperature.conf` | Конфигурация модуля |
| `/var/lib/lsm/state/temperature_alert` | Состояние алерта температуры |
| `/var/lib/lsm/state/temperature.state` | Состояние уведомлений (notify) |
| `/var/lib/lsm/state/temperature_check.lock` | Файл блокировки |

## Ручной запуск

```bash
# Краткий статус
/opt/lsm/modules/temperature/files/check_temperature.sh status

# Отчет по всем датчикам
/opt/lsm/modules/temperature/files/check_temperature.sh report

# Проверка с уведомлениями
sudo /opt/lsm/modules/temperature/files/check_temperature.sh check

# Управление службой
sudo systemctl restart lsm-temperature.timer
journalctl -u lsm-temperature.service -f
```

Коды выхода режима `check`: `0` = OK, `1` = WARNING, `2` = CRITICAL/ошибка окружения.

## Требования

- lm-sensors НЕ обязателен (есть фолбэк `/sys/class/thermal`). Для большего числа датчиков рекомендуется установить пакет `lm-sensors` и выполнить `sensors-detect`.
- systemd (таймер и служба).
- Библиотеки уведомлений LSM (опционально; без них работают только режимы status/report).

## Установка и удаление

```bash
# Установить модуль
lsm modules install temperature

# Включить/выключить таймер
lsm modules enable temperature
lsm modules disable temperature

# Удалить модуль
lsm modules remove temperature
```

Удаление останавливает таймер, убирает юниты systemd, конфигурацию `/etc/lsm/modules/temperature.conf` и все файлы состояния (`temperature_alert`, `temperature.state`, `temperature_check.lock`).
