#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Главный экран TUI
# Путь: lib/tui/screens/main.sh
# ==============================================================================


set -Eeuo pipefail


[[ -n "${LSM_TUI_MAIN_LOADED:-}" ]] && return 0
readonly LSM_TUI_MAIN_LOADED=1



#
# Главное окно
#

screen_main()
{

    ui_banner

    tui_main_menu

}



#
# Информация о системе
#

screen_info()
{

    local info


    info=$(cat <<EOF
Lite Server Monitor (LSM)

Версия:
${PROJECT_VERSION:-unknown}

Корень проекта:
${LSM_ROOT}

Состояние:
готов к работе
EOF
)



    tui_message \
        "Информация" \
        "${info}"

}



#
# Установка компонентов
#

screen_install()
{

    tui_message \
        "Установка" \
        "Мастер установки будет подключен через installer/wizard.sh"

}



#
# Конфигурация
#

screen_config()
{

    tui_message \
        "Конфигурация" \
        "Раздел настройки LSM"

}



#
# Отчеты
#

screen_report()
{

    tui_message \
        "Отчеты" \
        "Ежедневные отчеты и журнал событий"

}



#
# Диагностика
#

screen_doctor()
{

    tui_message \
        "Диагностика" \
        "Проверка компонентов LSM"

}
