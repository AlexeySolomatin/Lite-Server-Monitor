# Модуль мониторинга дисков

Модуль отслеживает заполнение смонтированных файловых систем и отправляет уведомления при превышении настраиваемых порогов. Поддерживает исключение отдельных точек монтирования, подавление повторных алертов и recovery-уведомления.

## Назначение

- Раннее предупреждение о переполнении дисков.
- Информационная поддержка: краткий статус (`status`) и таблица всех контролируемых ФС (`report`).

## Принцип работы

Данные получают командой `df -P`. Виртуальные/псевдо-ФС (proc, tmpfs, overlay и т.п.), loop-устройства и CD-ROM пропускаются автоматически; дополнительно можно исключить точки монтирования через `IGNORE_MOUNTS` (точное совпадение или вложенные пути).

Пороги:

| Уровень | Условие |
|---------|---------|
| WARNING | заполнение ≥ `WARNING%`; отправляется только если включены алерты |
| CRITICAL | заполнение ≥ `CRITICAL%`; эскалация с WARNING на CRITICAL отправляется всегда |
| OK (recovery) | все ФС вернулись в норму после алерта; только при `NOTIFY_ON_RECOVERY=true` |

Состояние уведомлений (`throttling`, эскалация, recovery) полностью принадлежит `lib/notifications/notify.sh` и хранится в `/var/lib/lsm/state/disk.state`. Повторная отправка алертов ограничена кулдауном `ALERT_COOLDOWN` (настраивается глобально). Режимы `status`/`report` не отправляют уведомлений и не меняют состояние.

Запуск выполняется таймером systemd `lsm-disk.timer`: каждые 5 минут. Параллельный запуск блокируется через `flock`.

## Параметры конфигурации

Файл: `/etc/lsm/modules/disk.conf`

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `WARNING` | `80` | WARNING-порог заполнения ФС, %. |
| `CRITICAL` | `90` | CRITICAL-порог заполнения ФС, %. Должен быть больше `WARNING`. |
| `IGNORE_MOUNTS` | `/snap /boot /boot/efi` | Точки монтирования для исключения через пробел (в коде fallback — пустая строка). |
| `NOTIFY_ON_ALERT` | `true` | Отправлять WARNING/CRITICAL-алерты. |
| `NOTIFY_ON_RECOVERY` | `true` | Отправлять recovery-уведомление (OK) при возврате в норму. |

## Файлы модуля

| Путь | Назначение |
|------|-----------|
| `modules/disk/files/check_disk.sh` | Скрипт проверки (в репозитории) |
| `/opt/lsm/modules/disk/files/check_disk.sh` | Скрипт проверки (в системе) |
| `/etc/systemd/system/lsm-disk.service` | Systemd-служба проверки |
| `/etc/systemd/system/lsm-disk.timer` | Systemd-таймер (каждые 5 минут) |
| `/etc/lsm/modules/disk.conf` | Конфигурация модуля |
| `/var/lib/lsm/state/disk.state` | Состояние уведомлений (notify) |
| `/var/lib/lsm/state/disk_check.lock` | Файл блокировки |

## Ручной запуск

```bash
# Краткий статус
/opt/lsm/modules/disk/files/check_disk.sh status

# Подробный отчет по файловым системам
/opt/lsm/modules/disk/files/check_disk.sh report

# Проверка с уведомлениями
sudo /opt/lsm/modules/disk/files/check_disk.sh check

# Управление службой
sudo systemctl restart lsm-disk.timer
journalctl -u lsm-disk.service -f
```

Коды выхода режима `check`: `0` = OK, `1` = WARNING, `2` = CRITICAL/ошибка окружения.

## Требования

- Утилита `df` (coreutils) — обязательна.
- systemd (таймер и служба).
- Библиотеки уведомлений LSM (опционально; без них работают только режимы status/report).

## Установка и удаление

```bash
# Установить модуль
lsm modules install disk

# Включить/выключить таймер
lsm modules enable disk
lsm modules disable disk

# Удалить модуль
lsm modules remove disk
```

Удаление останавливает таймер, убирает юниты systemd, конфигурацию `/etc/lsm/modules/disk.conf` и файлы состояния (`disk.state`, `disk_check.lock`).
