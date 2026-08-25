# Модуль мониторинга SMART

Модуль контролирует здоровье физических накопителей (HDD и SSD) через утилиту `smartctl` из пакета `smartmontools`. При сбое SMART отправляется уведомление CRITICAL, а после восстановления статуса — recovery-уведомление.

## Назначение

- Раннее обнаружение отказов дисков по общему статусу SMART.
- Контроль каждого накопителя отдельно (per-disk состояние алертов).
- Информационная поддержка: краткий статус (`status`) и подробный отчет (`report`).

## Принцип работы

- Устройства определяются автоматически в `/dev` (`sd*`, `nvme*`, `vd*`, `xvd*`, без loop/ram).
- Проверка выполняется командой `smartctl -H <устройство>`; ненулевой код выхода трактуется как сбой.
- Для каждого диска ведется свой файл состояния `smart_alert_<диск>`: алерт отправляется один раз, повторные уведомления не спамят.
- Когда диск снова проходит проверку, состояние снимается и (при `NOTIFY_ON_RECOVERY=true`) отправляется recovery-сообщение.
- Температура дисков (атрибут 194 `Temperature_Celsius`) показывается только в режиме `report` при `REPORT_TEMPERATURE=true`. Алертов по температуре модуль не формирует.
- Запуск выполняется таймером systemd `lsm-smart.timer`: первый запуск через 5 минут после загрузки, далее каждые 1 час.
- Повторная отправка алертов ограничена кулдауном `ALERT_COOLDOWN` (настраивается глобально, см. документацию LSM).
- Параллельный запуск проверки блокируется через `flock`.

Уровни уведомлений:

| Уровень | Условие |
|---------|---------|
| WARNING | не используется модулем |
| CRITICAL | smartctl -H завершился с ненулевым кодом (сбой SMART) |

## Параметры конфигурации

Файл: `/etc/lsm/modules/smart.conf`

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `IGNORE_DEVICES` | `""` | Устройства, исключаемые из проверки. Пробел-разделитель; можно указывать `sda` или `/dev/sda` (сравнение по basename). |
| `NOTIFY_ON_FAILURE` | `true` | Отправлять CRITICAL-уведомление при обнаружении сбоя SMART. |
| `NOTIFY_ON_RECOVERY` | `true` | Отправлять recovery-уведомление (OK), когда статус диска восстановился после алерта. |
| `REPORT_TEMPERATURE` | `true` | Показывать колонку температуры дисков в режиме `report`. Только отображение, без алертов. |

## Файлы модуля

| Путь | Назначение |
|------|-----------|
| `modules/smart/files/check_smart.sh` | Скрипт проверки (в репозитории) |
| `/opt/lsm/modules/smart/files/check_smart.sh` | Скрипт проверки (в системе) |
| `/etc/systemd/system/lsm-smart.service` | Systemd-служба проверки |
| `/etc/systemd/system/lsm-smart.timer` | Systemd-таймер (каждый час) |
| `/etc/lsm/modules/smart.conf` | Конфигурация модуля |
| `/var/lib/lsm/state/smart_alert_<диск>` | Файлы per-disk алертов |
| `/var/lib/lsm/state/smart.state` | Состояние уведомлений (notify) |
| `/var/lib/lsm/state/smart_check.lock` | Файл блокировки |

## Ручной запуск

```bash
# Краткий статус
/opt/lsm/modules/smart/files/check_smart.sh status

# Подробный отчет (с температурой при REPORT_TEMPERATURE=true)
/opt/lsm/modules/smart/files/check_smart.sh report

# Проверка с уведомлениями
sudo /opt/lsm/modules/smart/files/check_smart.sh check

# Управление службой
sudo systemctl restart lsm-smart.timer
journalctl -u lsm-smart.service -f
```

Коды выхода режима `check`: `0` = OK, `1` = WARNING, `2` = CRITICAL/ошибка окружения.

## Требования

- Пакет `smartmontools` (утилита `smartctl`). Без него проверка пропускается без ошибок.
- Права `root` (запуск через systemd).
- systemd (таймер и служба).
- Библиотеки уведомлений LSM (опционально; без них работают только режимы status/report).

## Установка и удаление

```bash
# Установить модуль
lsm modules install smart

# Включить/выключить таймер
lsm modules enable smart
lsm modules disable smart

# Удалить модуль
lsm modules remove smart
```

Удаление останавливает таймер, убирает юниты systemd, конфигурацию `/etc/lsm/modules/smart.conf` и все файлы состояния (`smart_alert_*`, `smart.state`, `smart_check.lock`).
