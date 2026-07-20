#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# UPS Module Installer
# -----------------------------------------------------------------------------

set -Eeuo pipefail


MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


log_info "Installing UPS module..."


deploy_create_directory \
    "/opt/lsm/modules/ups"


deploy_install_file \
    "${MODULE_DIR}/files/check_ups.sh" \
    "/opt/lsm/modules/ups/check_ups.sh" \
    755


deploy_install_file \
    "${MODULE_DIR}/files/lsm-ups.service" \
    "/etc/systemd/system/lsm-ups.service"


deploy_install_file \
    "${MODULE_DIR}/files/lsm-ups.timer" \
    "/etc/systemd/system/lsm-ups.timer"


templates_install \
    "modules/ups.conf" \
    "/etc/lsm/modules/ups.conf"


log_success "UPS module installed."
