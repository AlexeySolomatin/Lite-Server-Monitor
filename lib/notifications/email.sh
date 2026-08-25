#!/usr/bin/env bash
# ==============================================================================
# Lite Server Monitor (LSM)
# Отправка уведомлений по электронной почте (Email)
#
# Путь:
#   lib/notifications/email.sh
#
# Назначение:
#   Доставка почтовых уведомлений LSM через SMTP.
#
# Конфигурация:
#
#   /etc/lsm/config.conf
#       EMAIL_ENABLED, ALERT_EMAIL / EMAIL_TO,
#       SMTP_SERVER, SMTP_PORT, SMTP_TLS, SMTP_FROM
#
#   /etc/lsm/secrets.conf
#       SMTP_USER, SMTP_PASS
#
# Порядок отправки:
#
#   1. msmtp  — если задан SMTP_SERVER и установлена утилита;
#   2. mail/mailx — резервный вариант без SMTP-настроек.
#
# Использование:
#
#   email.sh "Тема" "Текст сообщения"
#
# ==============================================================================


set -Eeuo pipefail



#
# Загрузка конфигурации и секретов.
#
# Основной конфиг: /etc/lsm/config.conf
# Резервный вариант (устаревший): /etc/lsm/notifications.conf
#

CONFIG_FILE="${NOTIFICATIONS_FILE:-/etc/lsm/config.conf}"

SECRETS_FILE="${SECRETS_FILE:-/etc/lsm/secrets.conf}"



if [[ -f "${CONFIG_FILE}" ]]; then

    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"

elif [[ -f "/etc/lsm/notifications.conf" ]]; then

    # shellcheck source=/dev/null
    source "/etc/lsm/notifications.conf"

fi


if [[ -f "${SECRETS_FILE}" ]]; then

    # shellcheck source=/dev/null
    source "${SECRETS_FILE}"

fi



#
# Безопасное считывание параметров вызова.
#

TITLE="${1:-Уведомление LSM}"

MESSAGE="${2:-}"



#
# Получатель.
#
# Поддерживаются оба имени переменной:
#
#   EMAIL_TO     — прямое указание получателя;
#   ALERT_EMAIL  — имя, используемое мастером установки.
#

EMAIL_TO="${EMAIL_TO:-${ALERT_EMAIL:-}}"



#
# Если получатель не указан — завершаем работу без ошибки.
#

if [[ -z "${EMAIL_TO:-}" ]]; then

    exit 0

fi



#
# Логирование при доступности Logging API.
#
# При прямом запуске logging.sh может быть не загружен,
# поэтому используется безопасная проверка.
#

_email_log()
{
    local level="$1"
    local message="$2"

    case "${level}" in

        info)
            if declare -f log_info >/dev/null 2>&1; then
                log_info "EMAIL" "${message}"
            fi
            ;;

        error)
            if declare -f log_error >/dev/null 2>&1; then
                log_error "EMAIL" "${message}"
            else
                echo "Ошибка: ${message}" >&2
            fi
            ;;

    esac
}



# ==============================================================================
# Отправка через msmtp (предпочтительный способ)
# ==============================================================================

email_send_msmtp()
{

    #
    # Временный конфиг msmtp создается в закрытом каталоге,
    # передается через -C и удаляется после отправки.
    #
    # Это позволяет использовать собранные мастером SMTP-параметры
    # без хранения пароля в постоянных файлах msmtp.
    #

    local tmp_dir

    local tmp_cfg


    if ! tmp_dir="$(mktemp -d)"; then

        _email_log error "Не удалось создать временный каталог для msmtp."

        return 1

    fi


    tmp_cfg="${tmp_dir}/msmtp.conf"


    chmod 700 "${tmp_dir}"



    {

        echo "defaults"
        echo "auth           on"
        echo "tls            ${SMTP_TLS:-on}"
        echo "tls_trust_file /etc/ssl/certs/ca-certificates.crt"
        echo "logfile        -"
        echo
        echo "account        lsm"
        echo "host           ${SMTP_SERVER}"
        echo "port           ${SMTP_PORT:-587}"
        echo "from           ${SMTP_FROM:-${EMAIL_TO}}"

        if [[ -n "${SMTP_USER:-}" ]]; then

            echo "user           ${SMTP_USER}"

            echo "password       ${SMTP_PASS:-}"

        else

            echo "auth           off"

        fi

        echo
        echo "account default : lsm"

    } > "${tmp_cfg}"



    chmod 600 "${tmp_cfg}"



    local rc=0


    printf '%s\n' "${MESSAGE}" \
        | msmtp \
            --file="${tmp_cfg}" \
            --read-recipients \
            "${EMAIL_TO}" \
        || rc=$?



    rm -rf "${tmp_dir}"



    if (( rc != 0 )); then

        _email_log error "msmtp завершился с ошибкой (код ${rc})."

        return 1

    fi


    return 0

}



# ==============================================================================
# Резервная отправка через mail/mailx
# ==============================================================================

email_send_mailx()
{

    local mail_cmd=""


    if command -v mail >/dev/null 2>&1; then

        mail_cmd="mail"

    elif command -v mailx >/dev/null 2>&1; then

        mail_cmd="mailx"

    else

        _email_log error "Утилиты msmtp и mail/mailx не найдены. Отправка отменена."

        return 1

    fi


    printf '%s\n' "${MESSAGE}" \
        | "${mail_cmd}" -s "LSM: ${TITLE}" "${EMAIL_TO}"

}



# ==============================================================================
# Выбор способа отправки
# ==============================================================================

if [[ -n "${SMTP_SERVER:-}" ]] && command -v msmtp >/dev/null 2>&1; then

    _email_log info "Отправка почтового уведомления через msmtp на ${EMAIL_TO}..."


    email_send_msmtp

else

    _email_log info "Отправка почтового уведомления на ${EMAIL_TO}..."


    email_send_mailx

fi
