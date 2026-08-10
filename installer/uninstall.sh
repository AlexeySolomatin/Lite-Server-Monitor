#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Главный скрипт удаления системы
# Путь: uninstall.sh
# ==============================================================================

set -Eeuo pipefail

# Безопасная инициализация LSM_ROOT (защита от ошибок readonly)
if [[ -z "${LSM_ROOT:-}" ]]; then
    LSM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

#
# Подключение библиотек ядра
#

source "${LSM_ROOT}/lib/core/colors.sh"
source "${LSM_ROOT}/lib/core/logging.sh"
source "${LSM_ROOT}/lib/core/common.sh"
source "${LSM_ROOT}/lib/core/checks.sh"
source "${LSM_ROOT}/lib/core/config.sh"

#
# Подключение библиотек инсталлятора
#

source "${LSM_ROOT}/lib/installer/deploy.sh"
source "${LSM_ROOT}/lib/installer/services.sh"
source "${LSM_ROOT}/lib/installer/modules.sh"

main() {
    local force_yes=false

    # Разбор аргументов (-y / --force)
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y|--yes|--force)
                force_yes=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    # Проверка прав root
    if declare -f check_root >/dev/null 2>&1; then
        check_root
    elif [[ $EUID -ne 0 ]]; then
        log_error "Для удаления LSM требуются права root (запустите с sudo)"
        exit 1
    fi

    # Вывод баннера (если функция существует)
    if declare -f ui_banner >/dev/null 2>&1; then
        ui_banner
    fi

    log_warn "Система Lite Server Monitor и все её компоненты будут удалены!"

    if [[ "${force_yes}" != "true" ]]; then
        echo
        read -rp "Продолжить удаление? [y/N]: " answer
        if [[ ! "${answer}" =~ ^[Yy]$ ]]; then
            log_info "Удаление отменено пользователем."
            exit 0
        fi
    fi

    echo

    #
    # 1. Удаление установленных модулей
    #
    log_info "Остановка и удаление модулей..."
    local installed_modules
    installed_modules="$(modules_installed_list)"

    if [[ -n "${installed_modules}" ]]; then
        for module in ${installed_modules}; do
            modules_remove "${module}" || log_warn "Не удалось полностью удалить модуль: ${module}"
        done
    else
        log_info "Установленные модули не найдены."
    fi

    #
    # 2. Остановка и удаление системных сервисов
    #
    log_info "Остановка системных служб LSM..."
    if declare -f services_exists >/dev/null 2>&1 && services_exists lsm.service; then
        services_stop_and_disable lsm.service
    elif command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet lsm.service 2>/dev/null; then
        systemctl stop lsm.service || true
        systemctl disable lsm.service || true
    fi

    if declare -f services_daemon_reload >/dev/null 2>&1; then
        services_daemon_reload
    fi

    #
    # 3. Удаление рабочих директорий
    #
    log_info "Удаление каталогов системы..."
    deploy_remove_directory /etc/lsm
    deploy_remove_directory /var/lib/lsm
    deploy_remove_directory /var/log/lsm

    #
    # 4. Удаление исполняемого файла CLI
    #
    log_info "Удаление CLI-бинарника..."
    deploy_remove_file /usr/local/bin/lsm

    #
    # 5. Удаление основной директории установки (/opt/lsm)
    #
    log_info "Удаление файлов программы..."
    deploy_remove_directory /opt/lsm

    echo
    log_success "Lite Server Monitor успешно и полностью удален из системы."
}

main "$@"
