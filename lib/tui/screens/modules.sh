#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Экран управления модулями
# Путь: lib/tui/screens/modules.sh
# ==============================================================================


set -Eeuo pipefail


#
# Загрузка API модулей
#

if [[ -f "${LSM_ROOT}/lib/installer/modules.sh" ]]; then
    # shellcheck source=/dev/null
    source "${LSM_ROOT}/lib/installer/modules.sh"
fi



#
# Экран списка модулей
#

screen_modules()
{

    tui_clear

    tui_title "Управление модулями LSM"


    echo


    if ! declare -f modules_list >/dev/null 2>&1; then

        tui_error "API управления модулями недоступно."

        tui_pause

        return 1

    fi



    local modules

    modules="$(modules_list || true)"



    if [[ -z "${modules}" ]]; then

        tui_warning "Модули не найдены."

    else

        tui_section "Доступные модули"

        echo "${modules}"

    fi


    echo


    tui_menu \
        "Установить модуль" \
        "Удалить модуль" \
        "Назад"



    case "${TUI_MENU_RESULT}" in


        1)

            screen_modules_install

            ;;


        2)

            screen_modules_remove

            ;;


        3)

            return 0

            ;;


    esac

}



#
# Установка модуля
#

screen_modules_install()
{

    tui_clear

    tui_title "Установка модуля"


    read -rp "Имя модуля: " module


    if [[ -z "${module}" ]]; then

        tui_error "Имя модуля не указано."

        tui_pause

        return

    fi



    if modules_install "${module}"; then

        tui_success "Модуль ${module} установлен."

    else

        tui_error "Ошибка установки модуля ${module}."

    fi


    tui_pause

}



#
# Удаление модуля
#

screen_modules_remove()
{

    tui_clear

    tui_title "Удаление модуля"


    read -rp "Имя модуля: " module


    if [[ -z "${module}" ]]; then

        tui_error "Имя модуля не указано."

        tui_pause

        return

    fi



    if modules_remove "${module}"; then

        tui_success "Модуль ${module} удален."

    else

        tui_error "Ошибка удаления модуля ${module}."

    fi


    tui_pause

}
