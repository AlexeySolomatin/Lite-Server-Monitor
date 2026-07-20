#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Login Module Uninstaller
# -----------------------------------------------------------------------------

set -Eeuo pipefail


deploy_remove_file \
    /etc/systemd/system/lsm-login.service


deploy_remove_file \
    /etc/systemd/system/lsm-login.timer


deploy_remove_file \
    /etc/lsm/modules/login.conf


deploy_remove_directory \
    /opt/lsm/modules/login


log_success "Login module removed."
