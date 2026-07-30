#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
# Lite Server Monitor (LSM)
# Installation Step 01 - Environment Check
# -----------------------------------------------------------------------------

set -Eeuo pipefail


readonly ENV_COMPONENT="ENVIRONMENT"



step_environment()
{

    print_section "Environment Check"



    #
    # Root
    #

    if ! is_root; then

        log_error "${ENV_COMPONENT}" \
            "This installer must be run as root."

        return 1

    fi


    log_success "${ENV_COMPONENT}" \
        "Running as root."



    #
    # Supported OS
    #

    if ! is_supported_os; then

        log_error "${ENV_COMPONENT}" \
            "Unsupported operating system."

        return 1

    fi


    log_success "${ENV_COMPONENT}" \
        "Supported operating system detected."



    #
    # Bash
    #

    if (( BASH_VERSINFO[0] < 5 )); then

        log_error "${ENV_COMPONENT}" \
            "Bash 5.0 or newer is required."

        return 1

    fi


    log_success "${ENV_COMPONENT}" \
        "Bash version: ${BASH_VERSION}"



    #
    # APT
    #

    if ! command_exists apt-get; then

        log_error "${ENV_COMPONENT}" \
            "apt-get not found."

        return 1

    fi


    log_success "${ENV_COMPONENT}" \
        "APT package manager found."



    #
    # Architecture
    #

    local architecture

    architecture="$(uname -m)"


    case "${architecture}" in

        x86_64|aarch64)

            log_success "${ENV_COMPONENT}" \
                "Supported architecture: ${architecture}"

            ;;


        *)

            log_error "${ENV_COMPONENT}" \
                "Unsupported architecture: ${architecture}"

            return 1

            ;;

    esac



    #
    # Internet
    #

    if has_internet; then


        log_success "${ENV_COMPONENT}" \
            "Internet connection available."


    else


        log_warn "${ENV_COMPONENT}" \
            "Internet connection unavailable."


    fi



    #
    # Memory
    #

    local memory_mb

    memory_mb="$(
        awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo
    )"


    memory_mb="${memory_mb:-0}"



    if (( memory_mb < 512 )); then


        log_error "${ENV_COMPONENT}" \
            "At least 512 MB RAM is required. Current: ${memory_mb} MB"


        return 1

    fi



    log_success "${ENV_COMPONENT}" \
        "Memory available: ${memory_mb} MB"



    #
    # Disk
    #

    local free_mb


    free_mb="$(
        df -Pm / |
        awk 'NR==2 {print $4}'
    )"


    free_mb="${free_mb:-0}"



    if (( free_mb < 1024 )); then


        log_error "${ENV_COMPONENT}" \
            "At least 1 GB free disk space is required. Current: ${free_mb} MB"


        return 1

    fi



    log_success "${ENV_COMPONENT}" \
        "Free disk space: ${free_mb} MB"



    #
    # Writable directories
    #

    for dir in /opt /etc /var; do


        if [[ ! -w "${dir}" ]]; then


            log_error "${ENV_COMPONENT}" \
                "Directory is not writable: ${dir}"


            return 1


        fi


    done



    log_success "${ENV_COMPONENT}" \
        "Filesystem permissions OK."



    #
    # Environment completed
    #

    log_success "${ENV_COMPONENT}" \
        "Environment check completed successfully."


    return 0

}
