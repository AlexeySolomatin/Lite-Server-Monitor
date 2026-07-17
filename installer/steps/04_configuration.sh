#!/usr/bin/env bash

step_configuration() {

    log_step "Installing configuration"

    templates_install \
        config/config \
        /etc/lsm/config.conf

}
