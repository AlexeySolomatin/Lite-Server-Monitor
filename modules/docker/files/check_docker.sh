#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Модуль мониторинга Docker
#
# Путь:
#   modules/docker/files/check_docker.sh
#
# Назначение:
#   Периодическая проверка состояния Docker:
#
#       - наличие Docker в системе и доступность демона;
#       - активность службы docker.service;
#       - наличие остановленных контейнеров;
#       - объем дискового пространства, занимаемого Docker
#         (образы + контейнеры + тома) относительно порога.
#
#   Уведомления отправляются через централизованный диспетчер LSM:
#
#       - CRITICAL — Docker не установлен / демон недоступен /
#                    служба docker.service остановлена;
#       - WARNING  — остановленные контейнеры (при
#                    STOPPED_CONTAINER_WARNING=true), превышение порога
#                    STORAGE_WARNING_GB;
#       - OK       — recovery после ранее отправленного алерта
#                    (отправляется только если алерт был).
#
# Режимы:
#
#   check_docker.sh status
#       Краткий текущий статус. Всегда возвращает exit 0.
#
#   check_docker.sh report
#       Подробный отчет: версия, служба, контейнеры, хранилище.
#       Всегда возвращает exit 0.
#
#   check_docker.sh check
#       Машинная проверка с уведомлениями.
#       Коды выхода: 0 = OK, 1 = WARNING, 2 = CRITICAL/ошибка окружения.
#
# ==============================================================================


set -Eeuo pipefail


#
# Сброс локали для предсказуемого вывода docker/systemctl
#

export LC_ALL=C

export LANG=C


#
# Каталоги проекта
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"


#
# Конфигурация модуля
#

CONFIG_FILE="/etc/lsm/modules/docker.conf"

if [[ -f "${CONFIG_FILE}" ]]; then

    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"

fi


#
# Значения по умолчанию
#

ENABLED="${ENABLED:-true}"

CHECK_SERVICE="${CHECK_SERVICE:-true}"

CHECK_CONTAINERS="${CHECK_CONTAINERS:-true}"

CHECK_STORAGE="${CHECK_STORAGE:-true}"

STOPPED_CONTAINER_WARNING="${STOPPED_CONTAINER_WARNING:-true}"

STORAGE_WARNING_GB="${STORAGE_WARNING_GB:-50}"

# Защита от нечислового значения порога в конфигурации

if [[ ! "${STORAGE_WARNING_GB}" =~ ^[0-9]+$ ]]; then

    STORAGE_WARNING_GB=50

fi


#
# Состояние / блокировка
#

STATE_DIR="/var/lib/lsm/state"

LOCK_FILE="${STATE_DIR}/docker_check.lock"


#
# Библиотеки ядра и система уведомлений
#

if [[ -f "${PROJECT_ROOT}/lib/core/common.sh" ]]; then

    # shellcheck source=/dev/null
    source "${PROJECT_ROOT}/lib/core/common.sh"

fi

if [[ -f "${PROJECT_ROOT}/lib/core/logging.sh" ]]; then

    # shellcheck source=/dev/null
    source "${PROJECT_ROOT}/lib/core/logging.sh"

fi

if [[ -f "${PROJECT_ROOT}/lib/notifications/notify.sh" ]]; then

    # shellcheck source=/dev/null
    source "${PROJECT_ROOT}/lib/notifications/notify.sh"

fi


#
# Резервные функции журналирования на случай,
# если библиотеки ядра недоступны
#

if ! declare -F log_info >/dev/null 2>&1; then
    log_info() { printf '%s\n' "$*"; }
fi

if ! declare -F log_warn >/dev/null 2>&1; then
    log_warn() { printf '%s\n' "$*" >&2; }
fi

if ! declare -F log_error >/dev/null 2>&1; then
    log_error() { printf '%s\n' "$*" >&2; }
fi

if ! declare -F log_success >/dev/null 2>&1; then
    log_success() { printf '%s\n' "$*"; }
fi


#
# Режим работы
#

MODE="${1:-check}"


# ==============================================================================
# Вспомогательные функции
# ==============================================================================

#
# Демон Docker отвечает на запросы.
#

docker_daemon_alive()
{
    docker info >/dev/null 2>&1
}


#
# Служба docker.service активна.
#

docker_service_active()
{
    systemctl is-active --quiet docker 2>/dev/null
}


#
# Преобразование размера из вывода docker в гигабайты (целое число).
#
# Поддерживаются суффиксы GB/GiB и TB/TiB; значения меньше 1 ГБ
# (MB/KB/B) дают 0.
#
# Дробная часть отбрасывается (усечение до целых гигабайт):
# такой точности достаточно для сравнения с порогом STORAGE_WARNING_GB,
# который задается целым числом.
#

to_gb()
{
    local raw="${1:-}"
    local num

    num="$(printf '%s' "${raw}" | grep -oE '^[0-9]+(\.[0-9]+)?' || true)"

    if [[ -z "${num}" ]]; then
        num="0"
    fi

    if [[ "${raw}" =~ TB|TiB ]]; then
        echo $(( ${num%.*} * 1024 ))
    elif [[ "${raw}" =~ GB|GiB ]]; then
        echo "${num%.*}"
    else
        echo "0"
    fi
}


#
# Сбор статистики по контейнерам.
# Результат — глобальные переменные CNT_TOTAL / CNT_RUNNING / CNT_STOPPED.
#

docker_collect_containers()
{
    local ps_output=""
    local running=0

    CNT_TOTAL=0
    CNT_RUNNING=0
    CNT_STOPPED=0

    ps_output="$(docker ps -a --format '{{.Status}}' 2>/dev/null || true)"

    if [[ -z "${ps_output}" ]]; then
        return 0
    fi

    CNT_TOTAL="$(printf '%s\n' "${ps_output}" | wc -l | tr -d ' ')"

    running="$(printf '%s\n' "${ps_output}" | grep -c '^Up' || true)"
    CNT_RUNNING="${running:-0}"

    CNT_STOPPED=$(( CNT_TOTAL - CNT_RUNNING ))

    return 0
}


#
# Сбор данных об использовании диска (docker system df).
# Результат — глобальные переменные IMG_SIZE / CNT_SIZE / VOL_SIZE /
# TOTAL_STORAGE_GB.
#

docker_collect_storage()
{
    local df_output=""
    local img_gb=0
    local cnt_gb=0
    local vol_gb=0

    IMG_SIZE="0B"
    CNT_SIZE="0B"
    VOL_SIZE="0B"
    TOTAL_STORAGE_GB=0

    df_output="$(docker system df 2>/dev/null || true)"

    if [[ -z "${df_output}" ]]; then
        return 0
    fi

    IMG_SIZE="$(printf '%s\n' "${df_output}" | awk '/Images/ {print $4; exit}')"
    CNT_SIZE="$(printf '%s\n' "${df_output}" | awk '/Containers/ {print $4; exit}')"
    VOL_SIZE="$(printf '%s\n' "${df_output}" | awk '/Local Volumes/ {print $5; exit}')"

    img_gb="$(to_gb "${IMG_SIZE}")"
    cnt_gb="$(to_gb "${CNT_SIZE}")"
    vol_gb="$(to_gb "${VOL_SIZE}")"

    TOTAL_STORAGE_GB=$(( img_gb + cnt_gb + vol_gb ))

    return 0
}


# ==============================================================================
# Краткий статус
# ==============================================================================

do_status()
{
    if ! command -v docker >/dev/null 2>&1; then

        printf 'Docker: не установлен\n'

        return 0

    fi


    local version
    version="$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo 'недоступен')"


    if ! docker_daemon_alive; then

        printf 'Docker: демон не отвечает (версия: %s)\n' "${version}"

        return 0

    fi


    printf 'Docker: работает (версия %s)\n' "${version}"


    if [[ "${CHECK_SERVICE}" == "true" ]]; then

        if docker_service_active; then
            printf 'Служба    : активна\n'
        else
            printf 'Служба    : ОСТАНОВЛЕНА\n'
        fi

    else

        printf 'Служба    : проверка отключена\n'

    fi


    if [[ "${CHECK_CONTAINERS}" == "true" ]]; then

        docker_collect_containers

        printf 'Контейнеры: всего %d (запущено %d, остановлено %d)\n' \
            "${CNT_TOTAL}" "${CNT_RUNNING}" "${CNT_STOPPED}"

    else

        printf 'Контейнеры: проверка отключена\n'

    fi


    if [[ "${CHECK_STORAGE}" == "true" ]]; then

        docker_collect_storage

        printf 'Хранилище : %d GB (порог %d GB)\n' \
            "${TOTAL_STORAGE_GB}" "${STORAGE_WARNING_GB}"

    else

        printf 'Хранилище : проверка отключена\n'

    fi


    #
    # Статус — информационный режим, всегда успешный код выхода.
    #

    return 0
}


# ==============================================================================
# Подробный отчет
# ==============================================================================

do_report()
{
    printf '================================================================\n'

    printf 'Отчет по Docker\n'

    printf '================================================================\n'


    if ! command -v docker >/dev/null 2>&1; then

        printf '\nDocker не установлен в системе.\n\n'

        return 0

    fi


    local version
    version="$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo 'недоступен')"


    printf '\nВерсия     : %s\n' "${version}"


    if ! docker_daemon_alive; then

        printf 'Демон      : НЕ ОТВЕЧАЕТ\n\n'

        return 0

    fi

    printf 'Демон      : работает\n'


    if [[ "${CHECK_SERVICE}" == "true" ]]; then

        if docker_service_active; then
            printf 'Служба     : активна\n'
        else
            printf 'Служба     : ОСТАНОВЛЕНА (docker.service inactive)\n'
        fi

    else

        printf 'Служба     : проверка отключена\n'

    fi


    if [[ "${CHECK_CONTAINERS}" == "true" ]]; then

        docker_collect_containers

        printf '\nКонтейнеры :\n'

        printf '  Всего      : %d\n' "${CNT_TOTAL}"

        printf '  Запущены   : %d\n' "${CNT_RUNNING}"

        printf '  Остановлены: %d\n' "${CNT_STOPPED}"

    else

        printf '\nПроверка контейнеров отключена (CHECK_CONTAINERS=false).\n'

    fi


    if [[ "${CHECK_STORAGE}" == "true" ]]; then

        docker_collect_storage

        printf '\nХранилище  :\n'

        printf '  Образы     : %s\n' "${IMG_SIZE}"

        printf '  Контейнеры : %s\n' "${CNT_SIZE}"

        printf '  Тома       : %s\n' "${VOL_SIZE}"

        printf '  Итого      : %d GB (порог предупреждения: %d GB)\n' \
            "${TOTAL_STORAGE_GB}" "${STORAGE_WARNING_GB}"

    else

        printf '\nПроверка хранилища отключена (CHECK_STORAGE=false).\n'

    fi


    printf '\n'


    #
    # Отчет не отправляет уведомления и всегда успешен.
    #

    return 0
}


# ==============================================================================
# Машинная проверка с уведомлениями
# ==============================================================================

do_check()
{
    #
    # Каталог состояния должен существовать ДО захвата блокировки.
    #

    mkdir -p "${STATE_DIR}"


    #
    # Защита от параллельного запуска.
    #

    exec 200>"${LOCK_FILE}"

    if ! flock -n 200; then

        log_info "DOCKER" "Пропуск: предыдущая проверка выполняется."

        exit 0

    fi


    local result=0
    local version


    #
    # 1. Наличие Docker.
    #

    if ! command -v docker >/dev/null 2>&1; then

        log_error "DOCKER" "Docker не установлен в системе."

        if declare -F notify >/dev/null 2>&1; then
            notify "docker" "CRITICAL" "❌ Docker не установлен в системе. Проверки модуля Docker невозможны."
        fi

        return 2

    fi


    #
    # 2. Доступность демона.
    #

    if ! docker_daemon_alive; then

        log_error "DOCKER" "Демон Docker не отвечает на запросы."

        if declare -F notify >/dev/null 2>&1; then
            notify "docker" "CRITICAL" "❌ Демон Docker не отвечает на запросы (docker info завершился с ошибкой)."
        fi

        return 2

    fi


    version="$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo 'неизвестно')"


    #
    # 3. Служба docker.service.
    #

    if [[ "${CHECK_SERVICE}" == "true" ]] && ! docker_service_active; then

        log_error "DOCKER" "Служба Docker остановлена (docker.service inactive)."

        if declare -F notify >/dev/null 2>&1; then
            notify "docker" "CRITICAL" "❌ Служба Docker остановлена (docker.service inactive). Версия: ${version}."
        fi

        return 2

    fi


    #
    # 4. Остановленные контейнеры.
    #

    if [[ "${CHECK_CONTAINERS}" == "true" ]]; then

        docker_collect_containers

        if [[ "${STOPPED_CONTAINER_WARNING}" == "true" ]] &&
           (( CNT_STOPPED > 0 )); then

            log_warn "DOCKER" "Обнаружено остановленных контейнеров: ${CNT_STOPPED} из ${CNT_TOTAL}."

            if declare -F notify >/dev/null 2>&1; then
                notify "docker" "WARNING" "⚠️ Обнаружены остановленные Docker-контейнеры (${CNT_STOPPED} из ${CNT_TOTAL})."
            fi

            result=1

        fi

    fi


    #
    # 5. Использование дискового пространства.
    #

    if [[ "${CHECK_STORAGE}" == "true" ]]; then

        docker_collect_storage

        if (( TOTAL_STORAGE_GB >= STORAGE_WARNING_GB )); then

            log_warn "DOCKER" "Использование диска Docker (${TOTAL_STORAGE_GB} GB) превысило порог ${STORAGE_WARNING_GB} GB."

            if declare -F notify >/dev/null 2>&1; then
                notify "docker" "WARNING" "⚠️ Docker занимает ${TOTAL_STORAGE_GB} GB дискового пространства (порог: ${STORAGE_WARNING_GB} GB).\n- Образы: ${IMG_SIZE}\n- Контейнеры: ${CNT_SIZE}\n- Тома: ${VOL_SIZE}"
            fi

            result=1

        fi

    fi


    #
    # 6. Все проверки пройдены — recovery (notify сам решает,
    #    был ли ранее отправленный алерт).
    #

    if (( result == 0 )); then

        docker_collect_containers

        log_success "DOCKER" "Docker работает штатно (версия ${version}). Запущено контейнеров: ${CNT_RUNNING}/${CNT_TOTAL}."

        if declare -F notify >/dev/null 2>&1; then
            notify "docker" "OK" "✅ Работа Docker нормализована (версия ${version}). Запущено контейнеров: ${CNT_RUNNING}/${CNT_TOTAL}."
        fi

    fi


    #
    # Module API: ненулевой код означает проблемное состояние.
    #

    return "${result}"
}


# ==============================================================================
# Диспетчер режимов Module API
# ==============================================================================

main()
{
    #
    # Если модуль отключен в конфигурации — завершаем работу без ошибок.
    #

    if [[ "${ENABLED}" != "true" ]]; then

        log_info "DOCKER" "Пропуск: модуль отключен в конфигурации (ENABLED=false)."

        return 0

    fi


    case "${MODE}" in

        status)

            do_status

            ;;

        report)

            do_report

            ;;

        check)

            do_check

            ;;

        *)

            printf 'Неизвестный режим: %s\n' "${MODE}" >&2
            printf 'Использование: %s {status|report|check}\n' "$0" >&2

            return 2

            ;;

    esac
}


main "$@"
