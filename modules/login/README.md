# Модуль контроля входов пользователей

Модуль отслеживает активность входов по SSH через журнал journald: информирует об успешных входах и предупреждает о неудачных попытках авторизации (признак подбора паролей).

## Назначение

- Информирование об успешных входах по SSH (кто, откуда, каким методом).
- Обнаружение неудачных попыток авторизации с алертом WARNING.
- Информационная поддержка: краткий статус (`status`) и сводка за сутки (`report`).

## Принцип работы

- Источник данных — `journalctl -u ssh -u sshd` (поддерживаются имена юнитов `ssh` и `sshd` для разных дистрибутивов); локаль принудительно `LC_ALL=C` для стабильного парсинга.
- В режиме `check` анализируется окно журнала за 2 минуты (периодичность таймера `lsm-login.timer` — 1 минута).
- Обрабатываются ВСЕ строки окна за запуск, а не только последняя: каждое событие хэшируется (`sha256sum` строки) и дедуплицируется по файлу `/var/lib/lsm/state/login_seen`, где хранятся записи вида `<epoch>:<hash>`. Перед каждым запуском записи старше ~10 минут вычищаются (окно 2 минуты × запас на сдвиг запусков таймера). Это заменяет устаревшие файлы `login_last` / `login_failed_last`.
- Успешные входы (при `NOTIFY_ON_LOGIN=true`) отправляются через `notify_info "login" "<сообщение>"` — информационное сообщение БЕЗ alert-семантики: оно доставляется сразу, не создает throttle-state и не влияет на lifecycle алертов модуля.
- Неудачные попытки (при `NOTIFY_ON_FAILED=true`) отправляются через `notify "login" "WARNING" "<сообщение>"` — с защитой от спама: повторные уведомления гасятся кулдауном `ALERT_COOLDOWN` (настраивается глобально, см. документацию LSM; состояние — `/var/lib/lsm/state/login.state`).
- Параллельный запуск проверки блокируется через `flock`.

Уровни уведомлений:

| Уровень | Условие |
|---------|---------|
| INFO (`notify_info`) | успешный SSH-вход |
| WARNING | неудачная попытка авторизации (`Failed password` / `Invalid user`) |

## Параметры конфигурации

Файл: `/etc/lsm/modules/login.conf`

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `MONITOR_SSH` | `true` | Мониторить успешные входы по SSH (`Accepted password/publickey`). |
| `MONITOR_FAILED` | `true` | Мониторить неудачные попытки входа (`Failed password` / `Invalid user`). |
| `NOTIFY_ON_LOGIN` | `true` | Отправлять `notify_info` при каждом новом успешном входе (без кулдауна). |
| `NOTIFY_ON_FAILED` | `true` | Отправлять алерт WARNING при неудачных попытках (с кулдауном `ALERT_COOLDOWN`). |

## Файлы модуля

| Путь | Назначение |
|------|-----------|
| `modules/login/files/check_login.sh` | Скрипт проверки (в репозитории) |
| `/opt/lsm/modules/login/files/check_login.sh` | Скрипт проверки (в системе) |
| `/etc/systemd/system/lsm-login.service` | Systemd-служба проверки |
| `/etc/systemd/system/lsm-login.timer` | Systemd-таймер (каждую минуту) |
| `/etc/lsm/modules/login.conf` | Конфигурация модуля |
| `/var/lib/lsm/state/login_seen` | Дедупликация обработанных событий (`<epoch>:<hash>`) |
| `/var/lib/lsm/state/login.state` | Состояние уведомлений (notify, кулдаун) |
| `/var/lib/lsm/state/login_check.lock` | Файл блокировки |

## Ручной запуск

```bash
# Краткий статус (события за окно 2 минуты)
/opt/lsm/modules/login/files/check_login.sh status

# Сводка за сутки
/opt/lsm/modules/login/files/check_login.sh report

# Проверка с уведомлениями
sudo /opt/lsm/modules/login/files/check_login.sh check

# Управление службой
sudo systemctl restart lsm-login.timer
journalctl -u lsm-login.service -f
```

Коды выхода режима `check`: `0` = OK, `1` = WARNING (неудачные попытки), `2` = CRITICAL/ошибка окружения.

## Требования

- Работающий journald (systemd-journald) с журналом юнитов ssh/sshd.
- systemd (таймер и служба).
- Права `root` (чтение журнала аутентификации, запуск через systemd).
- Дополнительные пакеты не требуются.
- Библиотеки уведомлений LSM (опционально; без них работают только режимы `status`/`report`).

## Установка и удаление

```bash
# Установить модуль
lsm modules install login

# Включить/выключить таймер
lsm modules enable login
lsm modules disable login

# Удалить модуль
lsm modules remove login
```

Удаление останавливает и отключает таймер, убирает юниты systemd (с последующим `daemon-reload`), конфигурацию `/etc/lsm/modules/login.conf`, файлы состояния `/var/lib/lsm/state/login_seen`, `/var/lib/lsm/state/login.state`, `/var/lib/lsm/state/login_check.lock` и каталог модуля `/opt/lsm/modules/login`.
