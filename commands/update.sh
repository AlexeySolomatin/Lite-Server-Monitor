#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# CLI Command: Update
# -----------------------------------------------------------------------------

set -Eeuo pipefail

LSM_ROOT="${LSM_ROOT:-/opt/lsm}"

if [[ -f "${LSM_ROOT}/lib/core/common.sh" ]]; then source "${LSM_ROOT}/lib/core/common.sh"; fi
if [[ -f "${LSM_ROOT}/lib/core/ui.sh" ]]; then source "${LSM_ROOT}/lib/core/ui.sh"; fi

check_root

log_info "Checking for Lite Server Monitor updates..."

if [[ -d "${LSM_ROOT}/.git" ]]; then
    log_info "Updating codebase via Git..."
    git -C "${LSM_ROOT}" pull --rebase || log_warn "Git pull failed. Proceeding with installation refresh..."
fi

log_info "Re-running installer to apply updates..."
exec bash "${LSM_ROOT}/installer/install.sh" "$@"
