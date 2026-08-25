# Lite Server Monitor (LSM)

## Расположение файлов после установки (Installation Layout)

Версия: 1.1

Актуализировано по состоянию кода 0.1.x.

---

# 1. Обзор каталогов

| Каталог / файл | Назначение |
|----------------|------------|
| `/opt/lsm` | Файлы программы (копия дерева проекта) |
| `/etc/lsm` | Конфигурация |
| `/var/lib/lsm` | State-файлы, отчеты, реестр модулей |
| `/var/log/lsm` | Журналы |
| `/usr/local/bin/lsm` | Символьная ссылка на CLI |

---

# 2. /opt/lsm — файлы программы

Полная копия дерева репозитория.

```text
/opt/lsm

├── bin/lsm                 Главная CLI-точка входа
│
├── commands/               Команды CLI
│   ├── help.sh
│   ├── version.sh
│   ├── status.sh
│   ├── report.sh
│   ├── modules.sh
│   ├── config.sh
│   ├── doctor.sh
│   ├── install.sh
│   ├── update.sh
│   └── uninstall.sh
│
├── installer/              Установщик и мастер настройки
│
├── lib/
│   ├── core/               Базовые библиотеки LSM
│   ├── installer/          Логика установки
│   └── notifications/      Диспетчер уведомлений и каналы доставки
│
├── modules/<name>/         Установленные модули
│
├── templates/              Шаблоны конфигурации
│
├── VERSION                 Текущая версия
└── CHANGELOG.md            История изменений
```

Права:

- каталоги — 755;
- файлы — 644;
- исполняемые скрипты (`*.sh`, `bin/lsm`) — +x.

---

# 3. /etc/lsm — конфигурация

| Файл | Назначение | Права |
|------|------------|-------|
| `config.conf` | Основные параметры: каналы уведомлений, SMTP, кулдаун алертов, ежедневный отчет | 600 |
| `secrets.conf` | Секреты: Telegram-токен, SMTP-пароль | 600, root:root |
| `modules/<name>.conf` | Конфигурация модуля `<name>` | 640 |

Примечания:

- Секреты читаются только из `secrets.conf`.
- `notifications.conf` — устаревший резервный вариант основного конфига,
  используется только при отсутствии `config.conf`.

---

# 4. /var/lib/lsm — состояние

| Путь | Назначение |
|------|------------|
| `modules/<name>.installed` | Метка установки модуля (дата) |
| `state/<module>.state` | Throttle-state уведомлений, формат `<timestamp>|<LEVEL>`. Владелец — notify.sh |
| `state/login_seen` | Хэши обработанных событий входа (модуль login) |
| `state/fail2ban_bans` | Кэш списка забаненных IP для diff-детекции (модуль fail2ban) |
| `state/smart_alert_<dev>` | Признак активного алерта по диску (модуль smart) |
| `state/<module>_check.lock` | Lock-файлы защиты от параллельного запуска |
| `reports/lsm-report-*.txt` | Сохраненные отчеты (`lsm report --save`) |

State-каталог создается автоматически при первом запуске проверок.

---

# 5. /var/log/lsm — журналы

Единый журнал LSM пишется через Logging API (`lib/core/logging.sh`)
в формате:

```text
YYYY-MM-DD HH:MM:SS [LEVEL] [COMPONENT] MESSAGE
```

Дополнительно вывод systemd-служб доступен через:

```bash
journalctl -u lsm-<module>.service
```

---

# 6. systemd-компоненты

Для каждого мониторингового модуля устанавливается пара:

```text
lsm-<module>.service    oneshot-служба запуска check_<module>.sh
lsm-<module>.timer      Расписание проверки
```

Особый случай:

```text
lsm-report.service       Ежедневный сводный отчет
lsm-report.timer         Устанавливаются системным модулем core
```

Управление включением/отключением модулей:

```bash
lsm modules enable <name>
lsm modules disable <name>
```

Включение выполняется через `systemctl enable --now lsm-<name>.timer`
(для core — `lsm-report.timer`).

---

# 7. CLI

После установки доступна команда:

```bash
/usr/local/bin/lsm → /opt/lsm/bin/lsm
```

Справка: `lsm help`.

---

# 8. Диагностика проблем

Проверка целостности установки:

```bash
sudo lsm doctor
```

Ручная полная очистка при поврежденном uninstall:

```bash
sudo systemctl stop 'lsm-*' 2>/dev/null || true; \
sudo rm -f /etc/systemd/system/lsm-*.{service,timer} && \
sudo systemctl daemon-reload && \
sudo rm -rf /opt/lsm /etc/lsm /var/log/lsm /var/lib/lsm /usr/local/bin/lsm && hash -r
```
