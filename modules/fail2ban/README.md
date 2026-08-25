# Модуль мониторинга Fail2Ban

Модуль отслеживает баны IP-адресов в Fail2Ban по принципу diff: текущий список забаненных IP сравнивается с предыдущим состоянием, при появлении новых банов отправляется уведомление WARNING, а после разблокировки — recovery-уведомление.

## Назначение

- Своевременное информирование о новых блокировках IP-адресов (признак подбора паролей или атаки).
- Информирование об окончании срока банов (recovery).
- Контроль доступности демона Fail2Ban.
- Информационная поддержка: краткий статус (`status`) и отчет по jail (`report`).

## Принцип работы

- Проверка выполняется таймером systemd `lsm-fail2ban.timer` каждые 5 минут (`Persistent=true`).
- Список активных jail берется из вывода `fail2ban-client status` (строка `Jail list`); локаль принудительно `LC_ALL=C` для стабильного парсинга.
- Для каждого выбранного jail список забаненных IP берется из `fail2ban-client status <jail>` (строка `Banned IP list`) и формируется в виде пар `<jail>:<IP>`.
- Принцип diff-банов: полученный список сортируется и сравнивается с кэшем `/var/lib/lsm/state/fail2ban_bans`:
  - новые записи → уведомление WARNING;
  - исчезнувшие записи → recovery-уведомление OK (только если ранее был отправлен алерт).
- Кэш `/var/lib/lsm/state/fail2ban_bans` обновляется после каждой проверки и не является дубликатом notify-state: файл `fail2ban.state` используется только диспетчером уведомлений для кулдауна.
- Опция `MONITOR_JAILS` ограничивает обработку выбранными jail (по умолчанию — все).
- Повторная отправка алертов ограничена кулдауном `ALERT_COOLDOWN` (настраивается глобально, см. документацию LSM).
- Параллельный запуск проверки блокируется через `flock`.

Уровни уведомлений:

| Уровень | Условие |
|---------|---------|
| CRITICAL | демон Fail2Ban не отвечает (`fail2ban-client ping` завершился с ошибкой) |
| WARNING | новые баны IP-адресов |
| OK | разблокировка IP после ранее отправленного алерта |

## Параметры конфигурации

Файл: `/etc/lsm/modules/fail2ban.conf`

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `MONITOR_JAILS` | `""` | Список jail для мониторинга. Формат: `""` или `"all"` — все jail; `"sshd"` — один jail; `"sshd,nginx-badbot"` — список через запятую. |
| `NOTIFY_ON_BAN` | `true` | Отправлять WARNING при новых банах IP-адресов. Кэш при этом обновляется независимо от значения. |
| `NOTIFY_ON_RECOVERY` | `true` | Отправлять recovery (OK), когда забаненные ранее IP разблокированы. |

## Файлы модуля

| Путь | Назначение |
|------|-----------|
| `modules/fail2ban/files/check_fail2ban.sh` | Скрипт проверки (в репозитории) |
| `/opt/lsm/modules/fail2ban/files/check_fail2ban.sh` | Скрипт проверки (в системе) |
| `/etc/systemd/system/lsm-fail2ban.service` | Systemd-служба проверки |
| `/etc/systemd/system/lsm-fail2ban.timer` | Systemd-таймер (каждые 5 минут) |
| `/etc/lsm/modules/fail2ban.conf` | Конфигурация модуля |
| `/var/lib/lsm/state/fail2ban_bans` | Diff-кэш забаненных IP (`<jail>:<IP>`) |
| `/var/lib/lsm/state/fail2ban.state` | Состояние уведомлений (notify, кулдаун) |
| `/var/lib/lsm/state/fail2ban_check.lock` | Файл блокировки |

## Ручной запуск

```bash
# Краткий статус
sudo /opt/lsm/modules/fail2ban/files/check_fail2ban.sh status

# Отчет по jail (сейчас / всего банов)
sudo /opt/lsm/modules/fail2ban/files/check_fail2ban.sh report

# Проверка с уведомлениями (diff-баны)
sudo /opt/lsm/modules/fail2ban/files/check_fail2ban.sh check

# Управление службой
sudo systemctl restart lsm-fail2ban.timer
journalctl -u lsm-fail2ban.service -f
```

Коды выхода режима `check`: `0` = OK, `1` = WARNING (новые баны), `2` = CRITICAL/ошибка окружения.

## Требования

- Установленный и запущенный Fail2Ban (`fail2ban-client`). Без него проверка пропускается без ошибок (exit 0).
- Права `root`: работа с сокетом fail2ban и запуск через systemd.
- systemd (таймер и служба).
- Библиотеки уведомлений LSM (опционально; без них работают только режимы `status`/`report`).

## Установка и удаление

```bash
# Установить модуль
lsm modules install fail2ban

# Включить/выключить таймер
lsm modules enable fail2ban
lsm modules disable fail2ban

# Удалить модуль
lsm modules remove fail2ban
```

Удаление останавливает и отключает таймер, убирает юниты systemd (с последующим `daemon-reload`), конфигурацию `/etc/lsm/modules/fail2ban.conf`, файлы состояния `/var/lib/lsm/state/fail2ban_bans`, `/var/lib/lsm/state/fail2ban.state`, `/var/lib/lsm/state/fail2ban_check.lock` и каталог модуля `/opt/lsm/modules/fail2ban`.
