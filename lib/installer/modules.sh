#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Библиотека управления модулями
# Путь: lib/installer/modules.sh
# ==============================================================================

set -Eeuo pipefail

[[ -n "${LSM_MODULES_LOADED:-}" ]] && return 0
readonly LSM_MODULES_LOADED=1

#
# Пути (безопасная инициализация без перезаписи readonly-переменной)
#

if [[ -z "${LSM_ROOT:-}" ]]; then
    LSM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

LSM_MODULES_DIR="${LSM_MODULES_DIR:-${LSM_ROOT}/modules}"
LSM_STATE_DIR="${LSM_STATE_DIR:-/var/lib/lsm}"
LSM_MODULE_STATE_DIR="${LSM_MODULE_STATE_DIR:-${LSM_STATE_DIR}/modules}"

#
# Проверка существования модуля
#

modules_exists()
{
    local module="${1:-}"

    [[ -n "${module}" ]] || return 1
    [[ -d "${LSM_MODULES_DIR}/${module}" ]]
}

#
# Путь к модулю
#

modules_path()
{
    local module="$1"

    echo "${LSM_MODULES_DIR}/${module}"
}

#
# Состояние установки
#

modules_is_installed()
{
    local module="$1"

    [[ -f "${LSM_MODULE_STATE_DIR}/${module}.installed" ]]
}

modules_mark_installed()
{
    local module="$1"

    mkdir -p "${LSM_MODULE_STATE_DIR}"

    date '+%Y-%m-%d %H:%M:%S' \
        > "${LSM_MODULE_STATE_DIR}/${module}.installed"
}

modules_clear_state()
{
    local module="$1"

    rm -f \
        "${LSM_MODULE_STATE_DIR}/${module}.installed"
}

#
# Установка модуля
#

modules_install()
{
    local module="${1:-}"

    [[ -n "${module}" ]] || {
        log_error "Имя модуля не указано"
        return 1
    }

    if ! modules_exists "${module}"; then
        log_error "Модуль не найден: ${module}"
        return 1
    fi

    if modules_is_installed "${module}"; then
        log_warn "Модуль уже установлен: ${module}"
        return 0
    fi

    local module_dir
    module_dir="$(modules_path "${module}")"

    local installer="${module_dir}/install.sh"

    if [[ ! -f "${installer}" ]]; then
        log_error "install.sh отсутствует: ${module}"
        return 1
    fi

    chmod +x "${installer}"

    log_info "Установка модуля: ${module}"

    if ! bash "${installer}"; then
        log_error "Установка завершилась ошибкой: ${module}"
        return 1
    fi

    modules_mark_installed "${module}"

    log_success "Модуль установлен: ${module}"

    return 0
}

#
# Удаление модуля
#

modules_remove()
{
    local module="${1:-}"

    if ! modules_exists "${module}"; then
        log_error "Модуль не найден: ${module}"
        return 1
    fi

    local module_dir
    module_dir="$(modules_path "${module}")"

    local uninstall="${module_dir}/uninstall.sh"

    if [[ -f "${uninstall}" ]]; then
        chmod +x "${uninstall}"

        log_info "Удаление модуля: ${module}"

        if ! bash "${uninstall}"; then
            log_error "Ошибка удаления: ${module}"
            return 1
        fi
    else
        log_warn "uninstall.sh отсутствует: ${module}"
    fi

    modules_clear_state "${module}"

    log_success "Модуль удален: ${module}"

    return 0
}

#
# Включение модуля
#

modules_enable()
{
    local module="$1"
    local module_dir

    module_dir="$(modules_path "${module}")"

    if [[ -x "${module_dir}/enable.sh" ]]; then
        "${module_dir}/enable.sh"
    else
        log_warn "enable.sh отсутствует или не исполняемый: ${module}"
    fi
}

#
# Отключение модуля
#

modules_disable()
{
    local module="$1"
    local module_dir

    module_dir="$(modules_path "${module}")"

    if [[ -x "${module_dir}/disable.sh" ]]; then
        "${module_dir}/disable.sh"
    else
        log_warn "disable.sh отсутствует или не исполняемый: ${module}"
    fi
}

#
# Статус модуля
#

modules_status()
{
    local module="$1"

    echo
    echo "Модуль: ${module}"

    if modules_is_installed "${module}"; then
        echo "Статус: установлен"
        echo -n "Дата установки: "
        cat "${LSM_MODULE_STATE_DIR}/${module}.installed"
    else
        echo "Статус: не установлен"
    fi

    echo
}

#
# Список установленных модулей
#

modules_installed_list()
{
    [[ -d "${LSM_MODULE_STATE_DIR}" ]] || return 0

    find "${LSM_MODULE_STATE_DIR}" \
        -name "*.installed" \
        -printf "%f\n" \
        | sed 's/.installed$//'
}
