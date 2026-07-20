#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Fail2Ban Module Uninstaller
# -----------------------------------------------------------------------------

set -Eeuo pipefail


deploy_remove_file \
    /etc/systemd/system/lsm-fail2ban.service


deploy_remove_file \
    /etc/systemd/system/lsm-fail2ban.timer


deploy_remove_file \
    /etc/lsm/modules/fail2ban.conf


deploy_remove_directory \
    /opt/lsm/modules/fail2ban


log_success "Fail2Ban module removed."
