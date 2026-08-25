#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Команда обновления системы
#
# Путь:
#   commands/update.sh
#
# Назначение:
#   Тихое обновление установленной копии LSM:
#
#     1. Загрузка актуального кода из репозитория;
#     2. Синхронизация кода в каталог установки;
#     3. Запуск установщика в режиме --update:
#
#            - без интерактивных вопросов;
#            - состав модулей сохраняется (из state-маркеров);
#            - конфигурация /etc/lsm сохраняется.
#
# Переменные окружения:
#
#   LSM_REPO_URL       URL репозитория (по умолчанию GitHub);
#   LSM_UPDATE_BRANCH  ветка обновления (по умолчанию main).
#
# ==============================================================================

set -Eeuo pipefail

LSM_ROOT="${LSM_ROOT:-/opt/lsm}"

if [[ -f "${LSM_ROOT}/lib/core/common.sh" ]]; then source "${LSM_ROOT}/lib/core/common.sh"; fi
if [[ -f "${LSM_ROOT}/lib/core/logging.sh" ]]; then source "${LSM_ROOT}/lib/core/logging.sh"; fi
if [[ -f "${LSM_ROOT}/lib/core/ui.sh" ]]; then source "${LSM_ROOT}/lib/core/ui.sh"; fi

#
# Резервные реализации.
#
# Команда обновления обязана работать даже на поврежденной установке:
# без этих шимов падение log_* под set -e убивает скрипт ДО загрузки
# нового кода, и установка не может обновить саму себя (замкнутый круг).
#

if ! declare -F log_info >/dev/null 2>&1; then
    log_info() { printf '%s\n' "$*"; }
fi

if ! declare -F log_warn >/dev/null 2>&1; then
    log_warn() { printf 'Предупреждение: %s\n' "$*" >&2; }
fi

if ! declare -F check_root >/dev/null 2>&1; then
    check_root() {
        if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
            echo "Ошибка: обновление требует прав root." >&2
            exit 1
        fi
    }
fi

check_root



LSM_REPO_URL="${LSM_REPO_URL:-https://github.com/AlexeySolomatin/Lite-Server-Monitor}"

LSM_UPDATE_BRANCH="${LSM_UPDATE_BRANCH:-main}"



echo "Обновление Lite Server Monitor..."

echo



#
# Каталог загрузки.
#

tmp_dir="$(mktemp -d)"

trap 'rm -rf "${tmp_dir}"' EXIT



log_info "Загрузка актуального кода: ${LSM_REPO_URL} (${LSM_UPDATE_BRANCH})"



if ! curl -fsSL \
        "${LSM_REPO_URL}/archive/refs/heads/${LSM_UPDATE_BRANCH}.tar.gz" \
        -o "${tmp_dir}/src.tar.gz"; then

    echo "Ошибка: не удалось скачать архив кода. Проверьте сеть." >&2

    exit 1

fi


tar -xzf "${tmp_dir}/src.tar.gz" -C "${tmp_dir}"


src_dir="$(find "${tmp_dir}" -mindepth 1 -maxdepth 1 -type d | head -n 1)"


if [[ -z "${src_dir}" || ! -d "${src_dir}" ]]; then

    echo "Ошибка: неожиданная структура архива." >&2

    exit 1

fi



#
# Синхронизация кода в каталог установки.
#
# Заменяются только каталоги с кодом; данные пользователя
# (/etc/lsm, /var/lib/lsm, /var/log/lsm) не затрагиваются.
#

for _dir in bin commands installer lib modules templates docs; do

    if [[ -d "${src_dir}/${_dir}" ]]; then

        rm -rf "${LSM_ROOT:?}/${_dir}"

        cp -r "${src_dir}/${_dir}" "${LSM_ROOT}/${_dir}"

    fi

done


for _file in VERSION bootstrap.sh CHANGELOG.md; do

    if [[ -f "${src_dir}/${_file}" ]]; then

        cp -f "${src_dir}/${_file}" "${LSM_ROOT}/${_file}"

    fi

done


#
# Права на исполнение для скриптов.
#

find "${LSM_ROOT}/bin" "${LSM_ROOT}/commands" "${LSM_ROOT}/installer" \
     "${LSM_ROOT}/lib" "${LSM_ROOT}/modules" \
     -type f -name "*.sh" -exec chmod +x {} + 2>/dev/null || true

chmod +x "${LSM_ROOT}/bin/lsm" 2>/dev/null || true



log_info "Код обновлен. Запуск установщика в режиме обновления..."



exec bash "${LSM_ROOT}/installer/install.sh" --update "$@"
