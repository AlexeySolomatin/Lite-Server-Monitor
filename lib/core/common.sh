#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Common initialization library
# -----------------------------------------------------------------------------

[[ -n "${LSM_COMMON_LOADED:-}" ]] && return
readonly LSM_COMMON_LOADED=1

#
# Project information
#

readonly PROJECT_NAME="Lite Server Monitor"
readonly PROJECT_SHORT_NAME="LSM"

readonly PROJECT_VERSION="0.1.0-dev"
readonly PROJECT_AUTHOR="Alexey Solomatin"
readonly PROJECT_LICENSE="MIT"

#
# Installation paths
#

readonly INSTALL_DIR="/opt/lsm"

readonly CONFIG_DIR="/etc/lsm"

readonly STATE_DIR="/var/lib/lsm"

readonly LOG_DIR="/var/log/lsm"

readonly RUN_DIR="/run/lsm"

readonly BIN_DIR="/usr/local/bin"

#
# Internal directories
#

readonly LIB_DIR="${PROJECT_ROOT}/lib"
readonly CORE_DIR="${LIB_DIR}/core"
readonly COMMANDS_DIR="${PROJECT_ROOT}/commands"
readonly INSTALLER_DIR="${PROJECT_ROOT}/installer"
readonly MODULES_DIR="${PROJECT_ROOT}/modules"
readonly TEMPLATES_DIR="${PROJECT_ROOT}/templates"

#
# Default configuration files
#

readonly CONFIG_FILE="${CONFIG_DIR}/config.conf"
readonly MODULES_FILE="${CONFIG_DIR}/modules.conf"
readonly NOTIFICATIONS_FILE="${CONFIG_DIR}/notifications.conf"
readonly THRESHOLDS_FILE="${CONFIG_DIR}/thresholds.conf"
readonly SECRETS_FILE="${CONFIG_DIR}/secrets.conf"

#
# Load core libraries
#

# shellcheck source=/dev/null
source "${CORE_DIR}/colors.sh"

# shellcheck source=/dev/null
source "${CORE_DIR}/logging.sh"

# shellcheck source=/dev/null
source "${CORE_DIR}/filesystem.sh"

# shellcheck source=/dev/null
source "${CORE_DIR}/checks.sh"

# shellcheck source=/dev/null
source "${CORE_DIR}/config.sh"

# shellcheck source=/dev/null
source "${CORE_DIR}/ui.sh"

# shellcheck source=/dev/null
source "${CORE_DIR}/utils.sh"
