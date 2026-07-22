#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Modules Command
# -----------------------------------------------------------------------------

set -Eeuo pipefail

source "${LSM_ROOT}/lib/core/logging.sh"

echo
echo "Lite Server Monitor Modules"
echo "==========================="
echo

printf "%-15s %-12s %s\n" "Module" "Status" "Description"
printf "%-15s %-12s %s\n" "------" "------" "-----------"

for module_dir in "${LSM_ROOT}/modules"/*; do

    [[ -d "${module_dir}" ]] || continue

    # shellcheck source=/dev/null
    source "${module_dir}/manifest.conf"

    if [[ -d "/opt/lsm/modules/${MODULE_NAME}" ]]; then
        STATUS="Installed"
    else
        STATUS="Available"
    fi

    printf "%-15s %-12s %s\n" \
        "${MODULE_NAME}" \
        "${STATUS}" \
        "${MODULE_DESCRIPTION}"

done

echo
