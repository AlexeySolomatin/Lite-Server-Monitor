#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Справка команд CLI
# Путь: commands/help.sh
# ==============================================================================

set -Eeuo pipefail

# Версия системы по умолчанию (если не передана из окружения)
LSM_VERSION="${LSM_VERSION:-0.1.3-alpha}"

show_general_help() {
    cat <<EOF

Lite Server Monitor (LSM) v${LSM_VERSION}
Система мониторинга и защиты Linux-серверов

Использование:
  lsm <команда> [опции]

Основные команды:
  install       Установка компонентов системы
  uninstall     Полное или частичное удаление LSM
  update        Обновление компонентов и модулей
  status        Текущее состояние системы и сервисов
  doctor        Диагностика и проверка окружения
  report        Формирование отчетов (daily / manual)
  config        Управление конфигурационными файлами
  modules       Управление модулями мониторинга
  tui           Запуск интерактивного текстового интерфейса
  version       Показать версию системы

Управление модулями:
  lsm modules list             Список установленных модулей
  lsm modules available        Список всех доступных модулей
  lsm modules info <module>    Подробная информация о модуле
  lsm modules install <module> Установка конкретного модуля
  lsm modules remove <module>  Удаление модуля
  lsm modules enable <module>  Включение таймера/сервиса
  lsm modules disable <module> Отключение таймера/сервиса

Общие флаги:
  -h, --help    Показать эту справку
  -v, --version Показать версию
  --no-color    Отключить цветной вывод

Примеры:
  lsm status
  lsm modules info smart
  lsm report --send

EOF
}

# Если передан конкретный раздел, можно расширить вывод в будущем
case "${1:-}" in
    modules)
        cat <<EOF

Использование: lsm modules <команда> [модуль]

Команды:
  list                 Вывести список установленных модулей
  available            Вывести доступные для установки модули
  info <module>        Детальная информация, статус и параметры
  install <module>     Установить выбранный модуль
  remove <module>      Удалить выбранный модуль
  enable <module>      Активировать systemd-таймер модуля
  disable <module>     Деактивировать systemd-таймер модуля

EOF
        ;;
    *)
        show_general_help
        ;;
esac
