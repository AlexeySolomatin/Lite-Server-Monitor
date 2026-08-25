# Модуль мониторинга ИБП (UPS)

Модуль отслеживает состояние источника бесперебойного питания через демон `apcupsd`: работу от сети или от батареи, уровень заряда и остаток времени автономной работы. При переходе на батарею, низком заряде или малом остатке времени отправляются уведомления.

## Назначение

- Немедленное оповещение о потере сетевого питания.
- Предупреждение о низком заряде батареи и малом остатке времени работы.
- Recovery-уведомление при восстановлении питания от сети.

## Принцип работы

Данные получают командой `apcaccess status`:

| Параметр | Поле apcaccess |
|----------|----------------|
| Статус (ONLINE/ONBATT) | `STATUS` |
| Заряд батареи | `BCHARGE` |
| Остаток времени | `TIMELEFT` (приводится к минутам) |

Состояния модуля: `ONLINE` (норма), `ON_BATTERY`, `WARNING` (низкий заряд), `CRITICAL` (критический заряд), `LOW_RUNTIME` (остаток времени ниже `RUNTIME_WARNING`, в том числе при работе от сети).

Уровни уведомлений:

| Уровень | Условие |
|---------|---------|
| WARNING | переход на батарею (`NOTIFY_ON_BATTERY`), низкий заряд или малый остаток времени (`NOTIFY_ON_LOW_BATTERY`) |
| CRITICAL | заряд ≤ `BATTERY_CRITICAL`; эскалация с WARNING на CRITICAL отправляется всегда |
| OK (recovery) | питание от сети восстановлено после алерта; только при `NOTIFY_ON_RECOVERY=true` |

Последнее состояние хранится в `/var/lib/lsm/state/ups_state` — уведомления отправляются только при смене состояния. Повторная отправка алертов также ограничена кулдауном `ALERT_COOLDOWN` (настраивается глобально).

Запуск выполняется таймером systemd `lsm-ups.timer`: первый запуск через 2 минуты после загрузки, далее каждую минуту. Параллельный запуск блокируется через `flock`.

## Параметры конфигурации

Файл: `/etc/lsm/modules/ups.conf`

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `BATTERY_WARNING` | `50` | WARNING-порог заряда батареи, %. |
| `BATTERY_CRITICAL` | `20` | CRITICAL-порог заряда батареи, %. |
| `RUNTIME_WARNING` | `10` | WARNING-порог остатка времени автономной работы, минуты. |
| `NOTIFY_ON_BATTERY` | `true` | Уведомлять о переходе на питание от батареи. |
| `NOTIFY_ON_LOW_BATTERY` | `true` | Уведомлять о низком заряде и малом остатке времени. |
| `NOTIFY_ON_RECOVERY` | `true` | Отправлять recovery-уведомление при восстановлении питания от сети. |
| `APCACCESS_BIN` | `apcaccess` | Путь к утилите apcaccess (если не в PATH). |

## Файлы модуля

| Путь | Назначение |
|------|-----------|
| `modules/ups/files/check_ups.sh` | Скрипт проверки (в репозитории) |
| `/opt/lsm/modules/ups/files/check_ups.sh` | Скрипт проверки (в системе) |
| `/etc/systemd/system/lsm-ups.service` | Systemd-служба проверки |
| `/etc/systemd/system/lsm-ups.timer` | Systemd-таймер (каждую минуту) |
| `/etc/lsm/modules/ups.conf` | Конфигурация модуля |
| `/var/lib/lsm/state/ups_state` | Последнее состояние ИБП |
| `/var/lib/lsm/state/ups.state` | Состояние уведомлений (notify) |
| `/var/lib/lsm/state/ups_check.lock` | Файл блокировки |

## Ручной запуск

```bash
# Краткий статус
/opt/lsm/modules/ups/files/check_ups.sh status

# Подробный отчет
/opt/lsm/modules/ups/files/check_ups.sh report

# Проверка с уведомлениями
sudo /opt/lsm/modules/ups/files/check_ups.sh check

# Управление службой
sudo systemctl restart lsm-ups.timer
journalctl -u lsm-ups.service -f
```

Коды выхода режима `check`: `0` = OK, `1` = WARNING, `2` = CRITICAL/ошибка окружения.

## Требования

- Установленный и работающий демон **apcupsd** — без него модуль пропускает проверку. Требуется настроенный apcupsd (`/etc/apcupsd/apcupsd.conf`) с доступом к ИБП; проверка выполняется через `apcaccess status`.
- systemd (таймер и служба).
- Библиотеки уведомлений LSM (опционально; без них работают только режимы status/report).

## Установка и удаление

```bash
# Установить модуль
lsm modules install ups

# Включить/выключить таймер
lsm modules enable ups
lsm modules disable ups

# Удалить модуль
lsm modules remove ups
```

Удаление останавливает таймер, убирает юниты systemd, конфигурацию `/etc/lsm/modules/ups.conf` и все файлы состояния (`ups_state`, `ups.state`, `ups_check.lock`).
