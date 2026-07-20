#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# RAID Module Installer
# -----------------------------------------------------------------------------

set -Eeuo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info "Installing RAID module..."

deploy_create_directory "/opt/lsm/modules/raid"

deploy_install_file \
    "${MODULE_DIR}/files/check_raid.sh" \
    "/opt/lsm/modules/raid/check_raid.sh" \
    755

deploy_install_file \
    "${MODULE_DIR}/files/lsm-raid.service" \
    "/etc/systemd/system/lsm-raid.service"

deploy_install_file \
    "${MODULE_DIR}/files/lsm-raid.timer" \
    "/etc/systemd/system/lsm-raid.timer"

templates_install \
    "modules/raid.conf" \
    "/etc/lsm/modules/raid.conf"

log_success "RAID module installed."
