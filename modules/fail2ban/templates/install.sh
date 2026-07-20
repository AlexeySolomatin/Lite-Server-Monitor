#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Fail2Ban Module Installer
# -----------------------------------------------------------------------------

set -Eeuo pipefail


MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


log_info "Installing Fail2Ban module..."


deploy_create_directory \
    "/opt/lsm/modules/fail2ban"


deploy_install_file \
    "${MODULE_DIR}/files/check_fail2ban.sh" \
    "/opt/lsm/modules/fail2ban/check_fail2ban.sh" \
    755


deploy_install_file \
    "${MODULE_DIR}/files/lsm-fail2ban.service" \
    "/etc/systemd/system/lsm-fail2ban.service"


deploy_install_file \
    "${MODULE_DIR}/files/lsm-fail2ban.timer" \
    "/etc/systemd/system/lsm-fail2ban.timer"


templates_install \
    "modules/fail2ban.conf" \
    "/etc/lsm/modules/fail2ban.conf"


log_success "Fail2Ban module installed."
