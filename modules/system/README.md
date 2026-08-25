# Модуль мониторинга системных ресурсов

Модуль следит за базовыми ресурсами сервера: загрузкой CPU (load average), использованием памяти и заполнением корневой файловой системы. При превышении порогов отправляются уведомления, при возврате в норму — recovery-сообщение.

## Назначение

- Быстрое обнаружение нехватки вычислительных ресурсов и переполнения корневого раздела.
- Сохранение локального снимка состояния для других инструментов LSM (`/var/lib/lsm/state/system.status`).

## Принцип работы

Источники данных:

| Метрика | Источник |
|---------|----------|
| Загрузка CPU | `/proc/loadavg` (значение за 1 минуту) |
| Память | `/proc/meminfo` (`MemTotal`, `MemAvailable`; при отсутствии `MemAvailable` используется `MemFree`) |
| Корневая ФС | `df -P /` |

Сравнение дробного load average выполняется через масштабирование значений x10 в целые числа. Общий статус — максимум по всем трем метрикам.

Запуск выполняется таймером systemd `lsm-system.timer`: первый запуск через 5 минут после загрузки, далее каждые 5 минут. Повторная отправка алертов ограничена кулдауном `ALERT_COOLDOWN` (настраивается глобально). Параллельный запуск блокируется через `flock`.

Уровни уведомлений:

| Уровень | Условие |
|---------|---------|
| WARNING | любая метрика превысила WARNING-порог; отправляется только при `NOTIFY_ON_WARNING=true` |
| CRITICAL | любая метрика превысила CRITICAL-порог; эскалация с WARNING на CRITICAL отправляется всегда |

## Параметры конфигурации

Файл: `/etc/lsm/modules/system.conf`

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `LOAD_WARNING` | `5.0` | WARNING-порог load average за 1 минуту. |
| `LOAD_CRITICAL` | `10.0` | CRITICAL-порог load average за 1 минуту. |
| `MEMORY_WARNING` | `85` | WARNING-порог использования памяти, %. |
| `MEMORY_CRITICAL` | `95` | CRITICAL-порог использования памяти, %. |
| `DISK_WARNING` | `85` | WARNING-порог заполнения корневой ФС /, %. |
| `DISK_CRITICAL` | `95` | CRITICAL-порог заполнения корневой ФС /, %. |
| `NOTIFY_ON_WARNING` | `true` | Отправлять WARNING-алерты (CRITICAL отправляются всегда). |
| `NOTIFY_ON_RECOVERY` | `true` | Отправлять recovery-уведомление (OK) при возврате всех метрик в норму. |

## Файлы модуля

| Путь | Назначение |
|------|-----------|
| `modules/system/files/check_system.sh` | Скрипт проверки (в репозитории) |
| `/opt/lsm/modules/system/files/check_system.sh` | Скрипт проверки (в системе) |
| `/etc/systemd/system/lsm-system.service` | Systemd-служба проверки |
| `/etc/systemd/system/lsm-system.timer` | Systemd-таймер (каждые 5 минут) |
| `/etc/lsm/modules/system.conf` | Конфигурация модуля |
| `/var/lib/lsm/state/system.status` | Последний снимок состояния |
| `/var/lib/lsm/state/system.state` | Состояние уведомлений (notify) |
| `/var/lib/lsm/state/system_check.lock` | Файл блокировки |

## Ручной запуск

```bash
# Краткий статус
/opt/lsm/modules/system/files/check_system.sh status

# Подробный отчет
/opt/lsm/modules/system/files/check_system.sh report

# Проверка с уведомлениями
sudo /opt/lsm/modules/system/files/check_system.sh check

# Управление службой
sudo systemctl restart lsm-system.timer
journalctl -u lsm-system.service -f
```

Коды выхода режима `check`: `0` = OK, `1` = WARNING, `2` = CRITICAL/ошибка окружения.

## Требования

- Дополнительные пакеты не требуются (используются `/proc`, `df`, coreutils).
- systemd (таймер и служба).
- Библиотеки уведомлений LSM (опционально; без них работают только режимы status/report).

## Установка и удаление

```bash
# Установить модуль
lsm modules install system

# Включить/выключить таймер
lsm modules enable system
lsm modules disable system

# Удалить модуль
lsm modules remove system
```

Удаление останавливает таймер, убирает юниты systemd, конфигурацию `/etc/lsm/modules/system.conf` и все файлы состояния (`system.status`, `system.state`, `system_check.lock`).
