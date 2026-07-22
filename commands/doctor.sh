#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Doctor Command
# -----------------------------------------------------------------------------

set -Eeuo pipefail

# Подключаем библиотеки UI и общих функций
LSM_ROOT="${LSM_ROOT:-/opt/lsm}"
if [[ -f "${LSM_ROOT}/lib/core/common.sh" ]]; then source "${LSM_ROOT}/lib/core/common.sh"; fi
if [[ -f "${LSM_ROOT}/lib/core/ui.sh" ]]; then source "${LSM_ROOT}/lib/core/ui.sh"; fi

ui_section "Lite Server Monitor Diagnostic"

echo
echo "Lite Server Monitor Diagnostic"
echo "=============================="
echo

#
# Root
#

if [[ $EUID -eq 0 ]]; then
    log_success "Running as root"
else
    log_error "Run as root"
fi

#
# Directories
#

check_dir() {

    local dir="$1"

    if [[ -d "${dir}" ]]; then
        log_success "${dir}"
    else
        log_error "${dir}"
    fi

}

echo
echo "Directories"

check_dir /etc/lsm
check_dir /opt/lsm
check_dir /var/lib/lsm
check_dir /var/log/lsm

#
# Services
#

echo
echo "Services"

systemctl list-unit-files | grep "^lsm-" || true

#
# Timers
#

echo
echo "Timers"

systemctl list-timers --all | grep "^lsm-" || true

#
# Disk space
#

echo
echo "Filesystem"

df -h /

echo
