#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# RAID Module Uninstaller
# -----------------------------------------------------------------------------

set -Eeuo pipefail

deploy_remove_file /etc/systemd/system/lsm-raid.service
deploy_remove_file /etc/systemd/system/lsm-raid.timer
deploy_remove_file /etc/lsm/modules/raid.conf
deploy_remove_directory /opt/lsm/modules/raid

log_success "RAID module removed."
