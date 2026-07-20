#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Temperature Module Installer
# -----------------------------------------------------------------------------

set -Eeuo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info "Installing Temperature module..."

deploy_create_directory "/opt/lsm/modules/temperature"

deploy_install_file \
    "${MODULE_DIR}/files/check_temperature.sh" \
    "/opt/lsm/modules/temperature/check_temperature.sh" \
    755

deploy_install_file \
    "${MODULE_DIR}/files/lsm-temperature.service" \
    "/etc/systemd/system/lsm-temperature.service"

deploy_install_file \
    "${MODULE_DIR}/files/lsm-temperature.timer" \
    "/etc/systemd/system/lsm-temperature.timer"

templates_install \
    "modules/temperature.conf" \
    "/etc/lsm/modules/temperature.conf"

log_success "Temperature module installed."
