#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Disk Module Uninstaller
# -----------------------------------------------------------------------------

set -Eeuo pipefail

services_stop_and_disable lsm-disk.timer

deploy_remove_file /etc/systemd/system/lsm-disk.service
deploy_remove_file /etc/systemd/system/lsm-disk.timer

deploy_remove_directory /opt/lsm/modules/disk

services_daemon_reload

log_success "Disk module removed."
