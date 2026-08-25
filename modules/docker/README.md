# Модуль мониторинга Docker

Модуль контролирует работу Docker: доступность демона, состояние службы `docker.service`, наличие остановленных контейнеров и объем дискового пространства, занимаемого образами, контейнерами и томами.

## Назначение

- Раннее обнаружение остановки демона или службы Docker.
- Контроль неожиданно остановленных или упавших (exited) контейнеров.
- Контроль дискового пространства, занятого подсистемой Docker.
- Информационная поддержка: краткий статус (`status`) и подробный отчет (`report`).

## Принцип работы

- Проверки выполняются таймером systemd `lsm-docker.timer` каждые 15 минут (`Persistent=true`).
- Доступность демона определяется командой `docker info`, версия — `docker version`.
- Активность службы проверяется через `systemctl is-active --quiet docker` (при `CHECK_SERVICE=true`).
- Статистика контейнеров собирается командой `docker ps -a`: контейнеры со статусом `Up` считаются запущенными, остальные — остановленными.
- Объем хранилища берется из `docker system df` (образы + контейнеры + тома) и сравнивается с порогом `STORAGE_WARNING_GB`. Значения усекаются до целых гигабайт.
- Параллельный запуск проверки блокируется через `flock` (файл `/var/lib/lsm/state/docker_check.lock`).
- Повторная отправка алертов ограничена кулдауном `ALERT_COOLDOWN` (настраивается глобально, см. документацию LSM). Recovery-уведомление (`OK`) отправляется только если ранее был отправлен алерт.

Уровни уведомлений:

| Уровень | Условие |
|---------|---------|
| CRITICAL | Docker не установлен; демон не отвечает; служба docker.service остановлена |
| WARNING | остановленные контейнеры (при `STOPPED_CONTAINER_WARNING=true`); превышен порог `STORAGE_WARNING_GB` |
| OK | recovery после ранее отправленного алерта |

Отсутствие Docker в системе — нормальное состояние для этого модуля: установка и режимы `status`/`report` работают без него и возвращают код выхода 0. В режиме `check` отсутствие Docker или недоступность демона трактуется как CRITICAL (код выхода 2), так как назначение модуля — контроль Docker.

## Параметры конфигурации

Файл: `/etc/lsm/modules/docker.conf`

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `ENABLED` | `true` | Включение/выключение модуля целиком. При `false` все запуски завершаются без ошибок. |
| `CHECK_SERVICE` | `true` | Проверять активность службы `docker.service`; при остановке — алерт CRITICAL. |
| `CHECK_CONTAINERS` | `true` | Собирать статистику контейнеров (всего / запущено / остановлено). |
| `CHECK_STORAGE` | `true` | Проверять объем диска, занятый Docker (`docker system df`). |
| `STOPPED_CONTAINER_WARNING` | `true` | Отправлять алерт WARNING при наличии остановленных контейнеров. |
| `STORAGE_WARNING_GB` | `50` | Порог суммарного объема (образы + контейнеры + тома) в ГБ; целое число. Превышение — алерт WARNING. |

## Файлы модуля

| Путь | Назначение |
|------|-----------|
| `modules/docker/files/check_docker.sh` | Скрипт проверки (в репозитории) |
| `/opt/lsm/modules/docker/files/check_docker.sh` | Скрипт проверки (в системе) |
| `/etc/systemd/system/lsm-docker.service` | Systemd-служба проверки |
| `/etc/systemd/system/lsm-docker.timer` | Systemd-таймер (каждые 15 минут) |
| `/etc/lsm/modules/docker.conf` | Конфигурация модуля |
| `/var/lib/lsm/state/docker.state` | Состояние уведомлений (notify) |
| `/var/lib/lsm/state/docker_check.lock` | Файл блокировки |

## Ручной запуск

```bash
# Краткий статус
/opt/lsm/modules/docker/files/check_docker.sh status

# Подробный отчет
/opt/lsm/modules/docker/files/check_docker.sh report

# Проверка с уведомлениями
sudo /opt/lsm/modules/docker/files/check_docker.sh check

# Управление службой
sudo systemctl restart lsm-docker.timer
journalctl -u lsm-docker.service -f
```

Коды выхода режима `check`: `0` = OK, `1` = WARNING, `2` = CRITICAL/ошибка окружения.

## Требования

- Docker — необязателен для установки модуля: без него `status`/`report` показывают «не установлен» (код 0), а `check` сообщает CRITICAL.
- systemd (таймер и служба).
- Права `root` (запуск через systemd).
- Библиотеки уведомлений LSM (опционально; без них работают только режимы `status`/`report`).

## Установка и удаление

```bash
# Установить модуль
lsm modules install docker

# Включить/выключить таймер
lsm modules enable docker
lsm modules disable docker

# Удалить модуль
lsm modules remove docker
```

Удаление останавливает и отключает таймер, убирает юниты systemd (с последующим `daemon-reload`), конфигурацию `/etc/lsm/modules/docker.conf`, файлы состояния `/var/lib/lsm/state/docker.state` и `/var/lib/lsm/state/docker_check.lock` и каталог модуля `/opt/lsm/modules/docker`.
