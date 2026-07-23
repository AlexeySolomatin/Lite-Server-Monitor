#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Главный экран TUI
# Путь: lib/tui/screens/main.sh
# ==============================================================================


set -Eeuo pipefail


[[ -n "${LSM_TUI_MAIN_LOADED:-}" ]] && return 0
readonly LSM_TUI_MAIN_LOADED=1



screen_main()
{

    wizard_init_tty


    while true
    do


        ui_banner


        tui_main_menu


        break


    done

}



#
# Дополнительные экраны-заглушки
# будут заменены отдельными модулями
#


screen_info()
{

    local info

    info=$(cat <<EOF
Lite Server Monitor (LSM)

Версия:
${PROJECT_VERSION:-unknown}

Корень:
${LSM_ROOT}

Состояние:
готов к работе
EOF
)


    tui_msg \
        "Информация" \
        "${info}"

}



screen_install()
{

    tui_msg \
        "Установка" \
        "Мастер установки будет перенесен из installer/wizard.sh"

}



screen_config()
{

    tui_msg \
        "Конфигурация" \
        "Раздел настройки LSM"

}



screen_report()
{

    tui_msg \
        "Отчеты" \
        "Ежедневные отчеты и журнал событий"

}



screen_doctor()
{

    tui_msg \
        "Диагностика" \
        "Проверка компонентов LSM"

}
