#!/usr/bin/env bash

step_packages() {

    log_step "Installing required packages"

    packages_update_cache

    packages_install \
        curl \
        wget \
        jq \
        bc \
        msmtp \
        smartmontools \
        mdadm \
        lm-sensors \
        fail2ban

}
