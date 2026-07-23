#!/usr/bin/env bash
#
# ==============================================================================
# Lite Server Monitor (LSM)
# Реестр компонентов установки
# Путь: lib/installer/registry.sh
# ==============================================================================


[[ -n "${LSM_INSTALL_REGISTRY_LOADED:-}" ]] && return 0
readonly LSM_INSTALL_REGISTRY_LOADED=1


LSM_MODULES_REGISTRY=()


LSM_MODULES_DIR="${LSM_MODULES_DIR:-${LSM_ROOT}/modules}"


#
# Регистрация модуля
#
registry_add()
{
    local module="$1"

    [[ -n "${module}" ]] || return 1

    LSM_MODULES_REGISTRY+=("${module}")
}


#
# Загрузка всех модулей из каталога
#
registry_scan()
{
    LSM_MODULES_REGISTRY=()


    if [[ ! -d "${LSM_MODULES_DIR}" ]]; then
        return 0
    fi


    while read -r module; do

        registry_add "${module}"

    done < <(
        find "${LSM_MODULES_DIR}" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -printf "%f\n" | sort
    )
}



#
# Проверка наличия
#
registry_exists()
{
    local name="$1"


    for module in "${LSM_MODULES_REGISTRY[@]}"
    do

        [[ "${module}" == "${name}" ]] && return 0

    done


    return 1
}



#
# Получить список
#
registry_list()
{
    printf "%s\n" "${LSM_MODULES_REGISTRY[@]}"
}



#
# Получить информацию модуля
#
registry_info()
{
    local module="$1"

    local manifest="${LSM_MODULES_DIR}/${module}/manifest.conf"


    if [[ -f "${manifest}" ]]; then

        # shellcheck source=/dev/null
        source "${manifest}"

        echo
        echo "Название: ${MODULE_TITLE}"
        echo "Описание: ${MODULE_DESCRIPTION}"
        echo "Категория: ${MODULE_CATEGORY}"
        echo "Версия: ${MODULE_VERSION}"
        echo

    else

        return 1

    fi
}



#
# Загрузка реестра по умолчанию
#
registry_load_default()
{
    registry_scan
}
