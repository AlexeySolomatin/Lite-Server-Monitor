#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Disk Module Uninstaller
# -----------------------------------------------------------------------------

set -Eeuo pipefail

# Останавливаем и отключаем службы
if command -v systemctl >/dev/null 2>&1; then
    systemctl disable --now lsm-disk.timer lsm-disk.service || true
    systemctl daemon-reload || true
fi

deploy_remove_file /etc/systemd/system/lsm-disk.service
deploy_remove_file /etc/systemd/system/lsm-disk.timer

deploy_remove_directory /opt/lsm/modules/disk

log_success "Disk module removed."
