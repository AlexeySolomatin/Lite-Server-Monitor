#!/usr/bin/env bash

step_directories() {

    log_info "Creating LSM directory structure..."

    deploy_create_directory /etc/lsm
    deploy_create_directory /etc/lsm/modules

    deploy_create_directory /opt/lsm
    deploy_create_directory /opt/lsm/scripts

    deploy_create_directory /var/log/lsm
    deploy_create_directory /var/lib/lsm

}
