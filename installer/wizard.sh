#!/usr/bin/env bash

declare -gA INSTALL_CONFIG

# shellcheck source=/dev/null
source "${PROJECT_ROOT}/installer/wizard/welcome.sh"

# shellcheck source=/dev/null
source "${PROJECT_ROOT}/installer/wizard/install_mode.sh"

# shellcheck source=/dev/null
source "${PROJECT_ROOT}/installer/wizard/notifications.sh"

# shellcheck source=/dev/null
source "${PROJECT_ROOT}/installer/wizard/smtp.sh"

# shellcheck source=/dev/null
source "${PROJECT_ROOT}/installer/wizard/ups.sh"

# shellcheck source=/dev/null
source "${PROJECT_ROOT}/installer/wizard/modules.sh"

# shellcheck source=/dev/null
source "${PROJECT_ROOT}/installer/wizard/summary.sh"

run_install_wizard() {

    wizard_welcome
    wizard_install_mode
    wizard_notifications
    wizard_smtp
    wizard_ups
    wizard_modules
    wizard_summary

}
