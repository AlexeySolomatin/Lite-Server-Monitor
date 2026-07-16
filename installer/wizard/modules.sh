#!/usr/bin/env bash

wizard_modules() {

    clear

    print_header

    echo "Monitoring Modules"
    echo

    INSTALL_CONFIG[disk]="true"
    INSTALL_CONFIG[smart]="true"
    INSTALL_CONFIG[raid]="true"
    INSTALL_CONFIG[temperature]="true"
    INSTALL_CONFIG[login_monitor]="true"
    INSTALL_CONFIG[fail2ban]="true"

    echo "Disk Monitor     : enabled"
    echo "SMART Monitor    : enabled"
    echo "RAID Monitor     : enabled"
    echo "Temperature      : enabled"
    echo "Login Monitor    : enabled"
    echo "Fail2Ban Monitor : enabled"
    echo
    echo "All recommended modules will be installed."
    echo

    pause

}
