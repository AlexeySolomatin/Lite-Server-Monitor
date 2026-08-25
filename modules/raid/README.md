# Модуль мониторинга RAID

Модуль контролирует состояние Linux software RAID массивов (`mdadm`): обнаруживает деградировавшие (degraded), отказавшие (failed) и неактивные (inactive) массивы. При обнаружении проблемы отправляется CRITICAL-уведомление, при восстановлении — recovery-сообщение.

## Назначение

- Немедленное оповещение о деградации или отказе RAID-массива.
- Информационная поддержка: краткий статус (`status`) и отчет по всем массивам (`report`).

## Принцип работы

Источники данных:

| Источник | Использование |
|----------|---------------|
| `/proc/mdstat` | Список активных массивов (`md*`) |
| `mdadm --detail /dev/mdN` | Строка `State:` каждого массива |

Массив считается проблемным, если строка `State:` содержит `degraded`, `failed` или `inactive`. Алерт отправляется один раз, пока проблема не устранена (состояние хранится в `/var/lib/lsm/state/raid_alert`); после восстановления отправляется recovery-уведомление. Повторная отправка алертов также ограничена кулдауном `ALERT_COOLDOWN` (настраивается глобально).

Запуск выполняется таймером systemd `lsm-raid.timer`: первый запуск через 3 минуты после загрузки, далее каждые 5 минут. Параллельный запуск блокируется через `flock`.

Уровни уведомлений:

| Уровень | Условие |
|---------|---------|
| WARNING | не используется модулем |
| CRITICAL | хотя бы один массив в состоянии degraded/failed/inactive |
| OK (recovery) | состояние всех массивов восстановлено после алерта; только при `NOTIFY_ON_RECOVERY=true` |

Если `/proc/mdstat` отсутствует, `mdadm` не установлен или нет прав root — проверка пропускается без ошибок.

## Параметры конфигурации

Файл: `/etc/lsm/modules/raid.conf`

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `NOTIFY_ON_FAILURE` | `true` | Отправлять CRITICAL-уведомление при обнаружении проблемного массива. |
| `NOTIFY_ON_RECOVERY` | `true` | Отправлять recovery-уведомление (OK) при восстановлении состояния. |
| `IGNORE_ARRAYS` | `""` | Массивы, исключаемые из проверки (пробел-разделитель): `"md0"` или `"/dev/md0"`. |

## Файлы модуля

| Путь | Назначение |
|------|-----------|
| `modules/raid/files/check_raid.sh` | Скрипт проверки (в репозитории) |
| `/opt/lsm/modules/raid/files/check_raid.sh` | Скрипт проверки (в системе) |
| `/etc/systemd/system/lsm-raid.service` | Systemd-служба проверки |
| `/etc/systemd/system/lsm-raid.timer` | Systemd-таймер (каждые 5 минут) |
| `/etc/lsm/modules/raid.conf` | Конфигурация модуля |
| `/var/lib/lsm/state/raid_alert` | Признак активного алерта RAID |
| `/var/lib/lsm/state/raid.state` | Состояние уведомлений (notify) |
| `/var/lib/lsm/state/raid_check.lock` | Файл блокировки |

## Ручной запуск

```bash
# Краткий статус
/opt/lsm/modules/raid/files/check_raid.sh status

# Подробный отчет по массивам
/opt/lsm/modules/raid/files/check_raid.sh report

# Проверка с уведомлениями
sudo /opt/lsm/modules/raid/files/check_raid.sh check

# Управление службой
sudo systemctl restart lsm-raid.timer
journalctl -u lsm-raid.service -f
```

Коды выхода режима `check`: `0` = OK, `1` = WARNING, `2` = CRITICAL/ошибка окружения.

## Требования

- Пакет `mdadm` и наличие software RAID (`/proc/mdstat`). Без mdadm проверка пропускается.
- Права `root`.
- systemd (таймер и служба).
- Библиотеки уведомлений LSM (опционально; без них работают только режимы status/report).

## Установка и удаление

```bash
# Установить модуль
lsm modules install raid

# Включить/выключить таймер
lsm modules enable raid
lsm modules disable raid

# Удалить модуль
lsm modules remove raid
```

Удаление останавливает таймер, убирает юниты systemd, конфигурацию `/etc/lsm/modules/raid.conf` и все файлы состояния (`raid_alert`, `raid.state`, `raid_check.lock`).
