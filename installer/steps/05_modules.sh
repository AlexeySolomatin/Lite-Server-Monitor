#!/usr/bin/env bash

step_modules() {

    log_step "Installing modules"

    for module in "${SELECTED_MODULES[@]}"; do
        modules_install "${module}"
    done

    #
    # Activate all installed services
    #

    services_daemon_reload

    for module in "${SELECTED_MODULES[@]}"; do

        local module_dir="${LSM_ROOT}/modules/${module}"

        if [[ -f "${module_dir}/manifest.conf" ]]; then

            # shellcheck source=/dev/null
            source "${module_dir}/manifest.conf"

            for service in "${MODULE_SERVICES[@]}"; do
                services_enable_and_start "${service}"
            done

        fi

    done

}
